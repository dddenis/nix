"""Restart idle Herdr agents through their current profile launchers."""

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
import fcntl
import json
import os
from pathlib import Path
import shlex
import signal
import stat
import subprocess
import sys
import time

from adapters import Unsupported, agent_process, codex_writer_owns_session, resume_arguments, session_header, shutdown_keys
from launch import get_launch, process_start, state_root


class ControlError(RuntimeError):
    def __init__(self, message, code=None):
        super().__init__(message)
        self.code = code


def command_json(binary, args, env, timeout=10, *, expect_json=True):
    completed = subprocess.run(
        [binary, *args], env=env, stdin=subprocess.DEVNULL,
        capture_output=True, text=True, timeout=timeout,
    )
    if completed.returncode == 0 and not expect_json:
        return None
    text = completed.stdout if completed.returncode == 0 else completed.stderr
    try:
        response = json.loads(text)
    except ValueError:
        raise ControlError(f"herdr {' '.join(args[:2])}: {text.strip() or 'empty response'}") from None
    if completed.returncode or "error" in response:
        error = response.get("error", {})
        raise ControlError(error.get("message", "Herdr command failed"), error.get("code"))
    return response.get("result", response)


class Client:
    def __init__(self, binary, session, lsof="lsof"):
        self.binary = binary
        self.lsof = lsof
        self.name = session["name"]
        self.socket_path = session["socket_path"]
        self.env = dict(os.environ)
        for key in ("HERDR_PANE_ID", "HERDR_TAB_ID", "HERDR_WORKSPACE_ID"):
            self.env.pop(key, None)
        self.env["HERDR_SOCKET_PATH"] = self.socket_path
        self.identity = self.socket_identity()

    def socket_identity(self):
        info = os.stat(self.socket_path)
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
            raise ControlError("Herdr socket is not a socket owned by this user")
        return info.st_dev, info.st_ino

    def call(self, *args, expect_json=True):
        if self.socket_identity() != self.identity:
            raise ControlError("Herdr server socket changed; rerun after checking the session")
        return command_json(self.binary, args, self.env, expect_json=expect_json)

    def agents(self):
        return self.call("agent", "list")["agents"]

    def agent(self, pane):
        return self.call("agent", "get", pane)["agent"]

    def pane(self, pane):
        return self.call("pane", "get", pane)["pane"]

    def processes(self, pane):
        return self.call("pane", "process-info", "--pane", pane)["process_info"]


def reference_key(reference):
    return tuple(reference.get(key) for key in ("agent", "kind", "value"))


def conversation_key(reference):
    if reference["kind"] == "path":
        header = session_header(reference["agent"], reference["value"])
        return header["id"], os.path.realpath(header["cwd"])
    return reference_key(reference)


def agent_identity(agent):
    return (
        agent["pane_id"], agent["terminal_id"], agent.get("agent"),
        reference_key(agent.get("agent_session") or {}), agent.get("state_change_seq"),
    )


def launch_argv(launch, native_args):
    args = [launch["launcher"]]
    if launch["safehouse_args"]:
        args += ["--safehouse", *launch["safehouse_args"], "--"]
    return [*args, *launch["agent_args"], *native_args]


@dataclass
class Plan:
    client: Client
    agent: dict
    process: dict
    process_started: str
    launch: dict
    reference: dict
    conversation: tuple
    keys: list | None
    argv: list
    shell_pid: int

    @property
    def pane(self):
        return self.agent["pane_id"]

    @property
    def label(self):
        return f"{self.client.name}/{self.pane} {self.agent['agent']}"

    @property
    def command(self):
        return f"cd -- {shlex.quote(self.launch['cwd'])} && {shlex.join(self.argv)}"


def make_plan(client, agent, profile_bin):
    if agent.get("agent_status") not in ("idle", "done"):
        raise Unsupported(f"state is {agent.get('agent_status', 'unknown')}")
    if agent.get("launch_pending"):
        raise Unsupported("agent startup is still pending")
    reference = agent.get("agent_session")
    if not reference or reference.get("agent") != agent.get("agent"):
        raise Unsupported("no matching saved session reference")
    processes = client.processes(agent["pane_id"])
    process = agent_process(agent["agent"], processes)
    shell_pid = processes.get("shell_pid")
    if not shell_pid or process["pid"] == shell_pid:
        raise Unsupported("agent replaced the pane shell; no shell to resume in")
    launch = get_launch(client.socket_path, agent, processes, profile_bin)
    expected = str(Path(profile_bin) / agent["agent"])
    if launch["launcher"] != expected:
        raise Unsupported("recorded launcher does not match the current profile launcher")
    if not os.path.isfile(expected) or not os.access(expected, os.X_OK):
        raise Unsupported(f"current profile launcher is unavailable: {expected}")
    native_args = resume_arguments(agent["agent"], reference, launch["cwd"])
    return Plan(
        client, agent, process, process_start(process["pid"]), launch, reference,
        conversation_key(reference), shutdown_keys(agent["agent"]),
        launch_argv(launch, native_args), shell_pid,
    )


def preflight(plan):
    # No session selector: --version must not open another writer on the transcript.
    # Removing Herdr context also prevents this probe from replacing a launch recipe.
    env = {key: value for key, value in os.environ.items() if not key.startswith("HERDR_")}
    completed = subprocess.run(
        launch_argv(plan.launch, ["--version"]), cwd=plan.launch["cwd"], env=env,
        stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=20,
    )
    if completed.returncode:
        raise ControlError(f"replacement launcher failed its --version check (exit {completed.returncode})")


def assert_unchanged(plan):
    info = plan.client.processes(plan.pane)
    current_process = agent_process(plan.agent["agent"], info)
    if (
        info.get("shell_pid") != plan.shell_pid
        or current_process["pid"] != plan.process["pid"]
        or current_process.get("argv") != plan.process.get("argv")
        or process_start(current_process["pid"]) != plan.process_started
        or process_start(plan.launch["launcher_pid"]) != plan.launch["launcher_start"]
    ):
        raise Unsupported("pane process identity changed")
    resume_arguments(plan.agent["agent"], plan.reference, plan.launch["cwd"])
    if conversation_key(plan.reference) != plan.conversation:
        raise Unsupported("saved conversation changed")
    # Lifecycle check is last, immediately before the stop request. Herdr has no
    # atomic restart-if-idle API; the user must not interact with selected panes.
    current = plan.client.agent(plan.pane)
    if current.get("agent_status") not in ("idle", "done") or agent_identity(current) != agent_identity(plan.agent):
        raise Unsupported("agent state or conversation changed since selection")


def process_exists(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def shell_ready(plan):
    pane = plan.client.pane(plan.pane)
    if pane["terminal_id"] != plan.agent["terminal_id"]:
        raise ControlError("pane terminal was replaced")
    info = plan.client.processes(plan.pane)
    if info.get("shell_pid") != plan.shell_pid:
        raise ControlError("pane shell was replaced")
    if (
        info.get("foreground_process_group_id") != plan.shell_pid
        or {process["pid"] for process in info.get("foreground_processes", [])} != {plan.shell_pid}
        or process_exists(plan.process["pid"])
    ):
        return False
    # Retire the previous occupant before launching: its cached session reference
    # must not be mistaken for a successful resume of the replacement process.
    try:
        plan.client.agent(plan.pane)
    except ControlError as error:
        if error.code == "agent_not_found":
            return True
        raise
    return False


def wait_until(check, timeout, description):
    deadline = time.monotonic() + timeout
    while True:
        result = check()
        if result:
            return result
        if time.monotonic() >= deadline:
            raise ControlError(f"timed out waiting for {description}; no force kill attempted")
        time.sleep(0.2)


def resumed_agent(plan):
    pane = plan.client.pane(plan.pane)
    if pane["terminal_id"] != plan.agent["terminal_id"]:
        raise ControlError("pane terminal changed during startup")
    try:
        agent = plan.client.agent(plan.pane)
    except ControlError as error:
        if error.code == "agent_not_found":
            return None
        raise
    if agent.get("agent") != plan.agent["agent"]:
        raise ControlError("a different agent appeared in the pane")
    reference = agent.get("agent_session")
    if reference and reference_key(reference) != reference_key(plan.reference):
        raise ControlError("replacement reported a different conversation")
    try:
        process = agent_process(plan.agent["agent"], plan.client.processes(plan.pane))
    except Unsupported:
        return None
    if process["pid"] == plan.process["pid"]:
        return None
    if agent.get("agent_status") == "blocked":
        raise ControlError("replacement needs user input; inspect the pane")
    if agent.get("agent_status") not in ("idle", "done"):
        return None
    if os.path.realpath(process["cwd"]) != os.path.realpath(plan.launch["cwd"]):
        raise ControlError("replacement has a different working directory")
    if not reference:
        if agent["agent"] != "codex":
            return None
        started = process_start(process["pid"])
        if not codex_writer_owns_session(process["pid"], plan.reference["value"], plan.client.lsof):
            return None
        if process_start(process["pid"]) != started:
            raise ControlError("replacement process changed during native session verification")
        if agent_identity(plan.client.agent(plan.pane)) != agent_identity(agent):
            return None
        plan.client.call(
            "pane", "report-agent-session", plan.pane,
            "--source", "herdr:codex", "--agent", "codex",
            "--seq", str(time.time_ns()),
            "--agent-session-id", plan.reference["value"],
            "--session-start-source", "resume", expect_json=False,
        )
        # Re-read Herdr's acknowledged identity on the next readiness check.
        return None
    resume_arguments(agent["agent"], reference, plan.launch["cwd"])
    if conversation_key(reference) != plan.conversation:
        raise ControlError("saved conversation identity changed during startup")
    return agent


def restart(plan, timeout):
    # Unsupported before the stop is a skip. Any later failure is actionable:
    # leave the pane alone and print the exact manual recovery command.
    preflight(plan)
    assert_unchanged(plan)
    print(f"RESTART {plan.label} ({plan.launch['origin']})", flush=True)
    try:
        if plan.keys is None:
            os.kill(plan.process["pid"], signal.SIGTERM)
        else:
            plan.client.call("agent", "send-keys", plan.pane, *plan.keys, expect_json=False)
        wait_until(lambda: shell_ready(plan), timeout, "the original agent to exit and its shell to return")
        resume_arguments(plan.agent["agent"], plan.reference, plan.launch["cwd"])
        if conversation_key(plan.reference) != plan.conversation:
            raise ControlError("saved conversation disappeared or changed after shutdown")
        if not shell_ready(plan):
            raise ControlError("pane is no longer at its shell prompt")
        plan.client.call("pane", "run", plan.pane, plan.command, expect_json=False)
        wait_until(lambda: resumed_agent(plan), timeout, "the same conversation to become ready")
        if plan.agent.get("name"):
            plan.client.call("agent", "rename", plan.pane, plan.agent["name"], expect_json=False)
    except (Unsupported, OSError, ValueError, ControlError, subprocess.SubprocessError) as error:
        raise ControlError(
            f"{error}\n  Inspect {plan.label} before retrying. If it is at a shell, recover with:\n  {plan.command}"
        ) from error
    print(f"RESTARTED {plan.label}", flush=True)


@contextmanager
def batch_lock():
    root = state_root()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = root.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ControlError(f"restart state directory must be private and owned by this user: {root}")
    fd = os.open(root / "batch.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ControlError("another herd-restart-agents invocation is running") from None
        yield
    finally:
        os.close(fd)


def run(args, binary, profile_bin, lsof):
    sessions = command_json(binary, ["session", "list", "--json"], os.environ)["sessions"]
    if args.session:
        missing = set(args.session) - {s["name"] for s in sessions if s.get("running")}
        if missing:
            raise ControlError(f"sessions not running: {', '.join(sorted(missing))}")
    restarted = skipped = failed = planned = 0
    for session in sessions:
        if not session.get("running") or (args.session and session["name"] not in args.session):
            continue
        try:
            client = Client(binary, session, lsof)
            agents = client.agents()
        except (ControlError, OSError, ValueError, subprocess.SubprocessError) as error:
            print(f"FAILED {session['name']}: {error}", file=sys.stderr)
            failed += 1
            continue
        for agent in agents:
            label = f"{session['name']}/{agent['pane_id']} {agent.get('agent', 'unknown')}"
            try:
                if (
                    os.environ.get("HERDR_PANE_ID") == agent["pane_id"]
                    and os.environ.get("HERDR_SOCKET_PATH") == client.socket_path
                ):
                    raise Unsupported("caller pane")
                plan = make_plan(client, agent, profile_bin)
                if args.dry_run:
                    print(f"WOULD RESTART {label} ({plan.launch['origin']})\n  {plan.command}")
                    planned += 1
                else:
                    restart(plan, args.timeout)
                    restarted += 1
            except Unsupported as error:
                print(f"SKIP {label}: {error}")
                skipped += 1
            except (ControlError, OSError, ValueError, subprocess.SubprocessError) as error:
                print(f"FAILED {label}: {error}", file=sys.stderr, flush=True)
                failed += 1
    if args.dry_run:
        print(f"Dry run: {planned} eligible, {skipped} skipped, {failed} failed; no agents stopped or launched.")
    else:
        print(f"{restarted} restarted, {skipped} skipped, {failed} failed.")
    return 1 if failed else 0


def main(argv=None, *, herdr="herdr", profile_bin=None, lsof="lsof"):
    parser = argparse.ArgumentParser(
        prog="herd-restart-agents",
        description="Restart idle/done agents in all running local Herdr sessions after a profile upgrade.",
        epilog="""Activate the new Home Manager generation first, then preview with --dry-run.
Saved conversations, working directories and supported launch options are retained.
Working/blocked/unknown agents and ambiguous launches are skipped. Recipes are
recorded by the managed agent wrappers; recognized older launches can be recovered.
Supported managed Safehouse launchers: omp, codex, claude and opencode.
Private recipes live in $XDG_STATE_HOME/herdr/restart, defaulting to
~/.local/state/herdr/restart. Agents need working Herdr state/session integrations;
non-default sockets may require an explicit Safehouse socket profile.
Codex's deferred session hook is supplemented by read-only native writer-lock
verification; a requested resume ID alone is never treated as proof of success.
Unsent drafts depend on the agent's own persistence. Do not interact with selected
panes during the batch: Herdr cannot atomically check idle state and stop an agent.
Startup dialogs are not answered automatically.
Shutdown/startup failures leave the pane alone and print a manual recovery command;
there is no force-kill fallback and nothing runs automatically on Nix activation.""",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--dry-run", action="store_true", help="show candidates, launch commands and skip reasons only")
    parser.add_argument("--session", action="append", metavar="NAME", help="limit to a named local Herdr session (repeatable; default: all running)")
    parser.add_argument("--timeout", type=float, default=30, metavar="SECONDS", help="each shutdown/startup wait deadline (default: 30; maximum: 300)")
    args = parser.parse_args(argv)
    if not 0 < args.timeout <= 300:
        parser.error("--timeout must be greater than zero and at most 300")
    profile_bin = profile_bin or str(Path.home() / ".nix-profile/bin")
    try:
        if args.dry_run:
            return run(args, herdr, profile_bin, lsof)
        with batch_lock():
            return run(args, herdr, profile_bin, lsof)
    except (ControlError, Unsupported, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"herd-restart-agents: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("herd-restart-agents: interrupted; inspect any pane already being restarted before retrying", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
