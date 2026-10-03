"""Private launch recipes and conservative reconstruction of older Safehouse launches."""

import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import sys
import tempfile

from adapters import Unsupported, agent_process, restart_options


KINDS = {"omp", "codex", "claude", "opencode"}
STORE = r"/nix/store/[a-z0-9]{32}-[^/]+"
SHELL = re.compile(STORE + r"/bin/(?:ba)?sh\Z")
SAFEHOUSE = re.compile(r"/nix/store/[a-z0-9]{32}-agent-safehouse-[^/]+/bin/safehouse\Z")
RELAY = re.compile(r"/(?:private/)?tmp/herdr-session-relays-[0-9]+/pane-[\w-]+/relay\.sb\Z")
BASE_FEATURES = {"agent-browser", "clipboard", "keychain", "process-control"}
FEATURES = BASE_FEATURES | {"docker", "microphone"}


def _ps(pid, field):
    try:
        result = subprocess.run(
            ["ps", "-p", str(pid), "-o", field + "="],
            capture_output=True, text=True, timeout=3, check=True,
            env={**os.environ, "LC_ALL": "C"},
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        raise Unsupported("cannot inspect launch process") from exc
    if not result:
        raise Unsupported("launch process no longer exists")
    return result


def process_start(pid: int) -> str:
    if type(pid) is not int or pid <= 1:
        raise Unsupported("invalid launch PID")
    return _ps(pid, "lstart")


def _ancestry(pid, shell_pid):
    chain = []
    while pid != shell_pid:
        if pid <= 1 or pid in chain or len(chain) >= 32:
            raise Unsupported("agent is not descended from this pane shell")
        chain.append(pid)
        parent = _ps(pid, "ppid")
        try:
            pid = int(parent)
        except ValueError as exc:
            raise Unsupported("invalid parent PID") from exc
    return chain


def _socket_identity(path):
    if not isinstance(path, str) or not os.path.isabs(path):
        raise Unsupported("missing absolute Herdr socket")
    info = os.stat(path)
    if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
        raise Unsupported("Herdr socket is not owned by this user")
    return [info.st_dev, info.st_ino]


def state_root() -> Path:
    """Return the metadata location without creating it (including in dry runs)."""
    return Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "herdr/restart"


def _directory(socket_path, create=False):
    root = state_root()
    directory = root / hashlib.sha256(socket_path.encode()).hexdigest()
    for path in (root, directory):
        if create:
            path.mkdir(mode=0o700, parents=True, exist_ok=True)
        if path.exists() or path.is_symlink():
            info = path.lstat()
            if (not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid()
                    or stat.S_IMODE(info.st_mode) != 0o700):
                raise Unsupported("launch metadata directory is not private")
    return directory


def _safe_options(args, *, legacy=False, kind=None):
    """Keep paths/features, never environment assignments or runtime relay policy."""
    result = []
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    defaults = {str(config / "safehouse/nix.sb")}
    if kind == "omp":
        defaults.add(str(config / "safehouse/omp.sb"))
    index = 0
    while index < len(args):
        token = args[index]
        index += 1
        key, equal, value = token.partition("=")
        if key not in {"--enable", "--env", "--append-profile", "--add-dirs", "--add-dirs-ro", "--env-pass"}:
            raise Unsupported("unsupported Safehouse option")
        # Bare --env means full environment, not a following filename.
        if key == "--env" and not equal:
            raise Unsupported("full environment Safehouse launch cannot be reconstructed")
        if not equal:
            if index >= len(args) or args[index].startswith("-"):
                raise Unsupported("missing Safehouse option value")
            value = args[index]
            index += 1
        if not value or any(ord(c) < 32 or ord(c) == 127 for c in value):
            raise Unsupported("invalid Safehouse option value")
        if key == "--enable":
            features = value.split(",")
            if any(feature not in FEATURES for feature in features):
                raise Unsupported("unsupported Safehouse feature")
            if legacy:
                features = [f for f in features if f not in BASE_FEATURES and not (kind == "omp" and f == "microphone")]
            result.extend("--enable=" + feature for feature in features)
        elif key == "--env-pass":
            if not legacy or value != "TMUX,TMUX_PANE":
                raise Unsupported("custom environment forwarding cannot be reconstructed")
        elif key == "--append-profile" and RELAY.fullmatch(value):
            if not legacy:
                raise Unsupported("runtime relay policy cannot be recorded")
        elif legacy and key == "--append-profile" and value in defaults:
            continue
        elif legacy and key == "--add-dirs-ro" and value == "/Applications/OrbStack.app/Contents/MacOS/xbin":
            continue
        else:
            result.append(key + "=" + value)
    return result


def _split_wrapper(args):
    safe, native = [], []
    index = 0
    while index < len(args):
        if args[index] != "--safehouse":
            native.append(args[index])
            index += 1
            continue
        index += 1
        while index < len(args) and args[index] != "--":
            safe.append(args[index])
            index += 1
        if index == len(args):
            raise Unsupported("unterminated Safehouse options")
        index += 1
    return _safe_options(safe), native


def _save(path, record):
    fd, temporary = tempfile.mkstemp(prefix=".recipe-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(record, stream, separators=(",", ":"))
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def record_main(argv=None) -> int:
    """Best effort: recording must never prevent an ordinary agent launch."""
    if os.environ.get("APP_SANDBOX_CONTAINER_ID") == "agent-safehouse":
        return 0
    socket_path = os.environ.get("HERDR_SOCKET_PATH")
    pane = os.environ.get("HERDR_PANE_ID", "")
    if not socket_path or not pane:
        return 0
    try:
        args = list(sys.argv[1:] if argv is None else argv)
        kind, launcher, pid_text, separator, *raw = args
        pid = int(pid_text)
        if kind not in KINDS or separator != "--" or pid != os.getppid():
            raise Unsupported("invalid recorder invocation")
        if not re.fullmatch(r"[\w-]+:[\w-]+", pane):
            raise Unsupported("invalid Herdr pane identity")
        if not os.path.isabs(launcher) or Path(launcher).name != kind or launcher.startswith("/nix/store/"):
            raise Unsupported("launcher is not a stable profile path")
        start = process_start(pid)
        record = {
            "version": 1, "agent": kind, "launcher": launcher,
            "cwd": os.getcwd(), "socket_path": socket_path,
            "socket_identity": _socket_identity(socket_path), "pane_id": pane,
            "launcher_pid": pid, "launcher_start": start,
        }
        try:
            safe, native = _split_wrapper(raw)
            safe = _safe_options(safe, legacy=True, kind=kind)
            record.update(safehouse_args=safe, agent_args=restart_options(kind, native, record["cwd"]))
            # Ambient browser arguments are otherwise lost by a new shell command.
            if os.environ.get("AGENT_BROWSER_ARGS"):
                raise Unsupported("custom browser environment")
        except (Unsupported, ValueError):
            record.pop("safehouse_args", None)
            record.pop("agent_args", None)
            record["unsupported"] = "original launch has unsupported options or environment"
        if process_start(pid) != start:
            raise Unsupported("launcher changed during recording")
        directory = _directory(socket_path, create=True)
        _save(directory / f"{pid}.json", record)
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        # No raw arguments, prompts, environment values or secrets in diagnostics.
        print("herd-restart-agents: could not record this launch", file=sys.stderr)
    return 0


def _read_record(path):
    info = path.lstat()
    if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
            or stat.S_IMODE(info.st_mode) != 0o600 or info.st_size > 65536):
        raise Unsupported("launch metadata is not a private bounded file")
    with path.open(encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise Unsupported("invalid launch metadata")
    return value


def _outer_options(process, kind, launcher, depth=0):
    """Recognize generated devenv delegates, not arbitrary shell programs."""
    argv = process.get("argv", [])
    if (depth > 3 or len(argv) < 2 or not SHELL.fullmatch(argv[0])
            or not re.fullmatch(STORE + r"(?:/bin/[^/]+)?", argv[1])):
        raise Unsupported("unrecognized outer launcher")
    path = Path(argv[1])
    if path.stat().st_size > 8192:
        raise Unsupported("outer launcher is not a simple delegate")
    text = path.read_text(encoding="utf-8")
    lines = [line.strip() for line in text.splitlines() if line.strip() and not line.lstrip().startswith("#")]
    if len(lines) != 1:
        raise Unsupported("outer launcher changes environment or runs extra commands")
    literal = lines[0]
    if not literal.endswith(' "$@"'):
        raise Unsupported("outer launcher does not quote forwarded arguments")
    literal = literal[:-5]
    for home_token in ('"$HOME/.nix-profile/bin/' + kind + '"',
                       '"${HOME}/.nix-profile/bin/' + kind + '"'):
        literal = literal.replace(home_token, shlex.quote(str(Path.home() / ".nix-profile/bin" / kind)))
    if any(character in literal for character in '$`;|&<>\\\\*?[]{}()'):
        raise Unsupported("outer launcher contains shell expansion or commands")
    words = shlex.split(lines[0])
    if len(words) < 3 or words[-1] != "$@":
        raise Unsupported("outer launcher does not forward arguments exactly")
    target = words[1].replace("${HOME}", str(Path.home())).replace("$HOME", str(Path.home()))
    if words[0] == "exec" and target == launcher:
        safe, native = _split_wrapper(words[2:-1] + argv[2:])
        return _safe_options(safe, legacy=True, kind=kind), native
    if SHELL.fullmatch(words[0]) and len(words) == 3:
        return _outer_options({"argv": words[:2] + argv[2:]}, kind, launcher, depth + 1)
    raise Unsupported("outer launcher is not a known stable-profile delegate")


def _legacy(process, kind, pane):
    argv = process.get("argv", [])
    if len(argv) < 3 or not SHELL.fullmatch(argv[0]) or not SAFEHOUSE.fullmatch(argv[1]):
        raise Unsupported("no recognized Safehouse launch")
    try:
        separator = argv.index("--", 2)
    except ValueError as exc:
        raise Unsupported("missing Safehouse command boundary") from exc
    safe = _safe_options(argv[2:separator], legacy=True, kind=kind)
    relay_profiles = [arg.removeprefix("--append-profile=") for arg in argv[2:separator]
                      if arg.startswith("--append-profile=") and RELAY.fullmatch(arg.removeprefix("--append-profile="))]
    rest = argv[separator + 1:]
    env = {}
    while rest and re.match(r"[A-Za-z_][A-Za-z0-9_]*=", rest[0]):
        key, value = rest.pop(0).split("=", 1)
        if key in env:
            raise Unsupported("duplicate Safehouse environment")
        env[key] = value
    expected = {"AGENT_BROWSER_ARGS": "--no-sandbox"}
    if kind == "opencode":
        expected["OPENCODE_ENABLE_EXA"] = "1"
    if kind == "codex" and "HERDR_ENV" in env:
        expected.update(HERDR_ENV="1", HERDR_PANE_ID=pane)
        relay = env.get("HERDR_SOCKET_PATH", "")
        profile = str(Path(relay).with_name("relay.sb"))
        if (not RELAY.fullmatch(profile) or Path(relay).name != "report.sock"
                or relay_profiles != [profile]):
            raise Unsupported("invalid legacy session relay")
        expected["HERDR_SOCKET_PATH"] = relay
    elif relay_profiles:
        raise Unsupported("relay policy has no matching Codex relay environment")
    if env != expected or not rest:
        raise Unsupported("custom or missing Safehouse command environment")
    command = rest[0]
    if kind == "omp":
        valid = re.fullmatch(r"/nix/store/[a-z0-9]{32}-omp-[^/]+/bin/omp", command)
    else:
        expected_command = Path.home() / (".local/bin/claude" if kind == "claude" else f".cache/.bun/bin/{kind}")
        valid = command == str(expected_command)
    if not valid:
        raise Unsupported("unrecognized Safehouse agent executable")
    return safe, rest[1:]


def _get_launch(socket_path, agent_info, process_info, profile_bin):
    socket_identity = _socket_identity(socket_path)
    kind = agent_info.get("agent")
    if kind not in KINDS or not os.path.isabs(profile_bin):
        raise Unsupported("unsupported agent or profile directory")
    launcher = os.path.join(profile_bin, kind)
    selected = agent_process(kind, process_info)
    pane = agent_info.get("pane_id")
    if process_info.get("pane_id") != pane:
        raise Unsupported("process information belongs to another pane")
    chain = _ancestry(selected["pid"], process_info.get("shell_pid"))
    processes = {p["pid"]: p for p in process_info.get("foreground_processes", [])}
    directory = _directory(socket_path)
    records = []
    for pid in chain:
        path = directory / f"{pid}.json"
        if path.exists() or path.is_symlink():
            records.append((pid, _read_record(path)))
    if len(records) > 1:
        raise Unsupported("multiple launch recipes in one process chain")
    # A foreground Safehouse ancestor explains the native argv and configuration.
    safehouses = [processes[pid] for pid in chain if pid in processes
                  and len(processes[pid].get("argv", [])) > 1
                  and SAFEHOUSE.fullmatch(processes[pid]["argv"][1])]
    if len(safehouses) != 1:
        raise Unsupported("expected exactly one Safehouse launcher")
    process = safehouses[0]
    pid = process["pid"]
    start = process_start(pid)
    cwd = process.get("cwd")
    if not isinstance(cwd, str) or not os.path.isabs(cwd) or cwd != selected.get("cwd"):
        raise Unsupported("launcher and agent working directories differ")
    safe, native = _legacy(process, kind, pane)
    options = restart_options(kind, native, cwd)
    if options != restart_options(kind, selected["agent_args"], cwd):
        raise Unsupported("agent options differ from launch options")
    # Only Codex's documented Node trampoline may sit between Safehouse and native.
    for intermediate_pid in chain[1:chain.index(pid)]:
        intermediate = processes.get(intermediate_pid, {})
        argv = intermediate.get("argv", [])
        if (kind != "codex" or len(argv) < 2 or Path(argv[0]).name != "node"
                or argv[1] != str(Path.home() / ".cache/.bun/bin/codex")
                or restart_options(kind, argv[2:], cwd) != options):
            raise Unsupported("unrecognized process between Safehouse and agent")
    safehouse_pid, safehouse_start = pid, start
    if records:
        pid, record = records[0]
        if chain.index(pid) < chain.index(safehouse_pid):
            raise Unsupported("launch metadata belongs to a process inside Safehouse")
        start = process_start(pid)
        for key, value in {"version": 1, "agent": kind, "launcher": launcher,
                           "cwd": cwd, "socket_path": socket_path,
                           "socket_identity": socket_identity, "pane_id": pane,
                           "launcher_pid": pid, "launcher_start": start}.items():
            if record.get(key) != value:
                raise Unsupported("launch metadata does not match the live launcher")
        if "unsupported" in record:
            raise Unsupported("original launch was recorded as unsupported")
        if record.get("safehouse_args") != safe or record.get("agent_args") != options:
            raise Unsupported("recorded options differ from the live launcher")
        # The managed wrapper and current relay preserve this PID through exec.
        # Its recipe captures project options without reparsing outer wrappers.
    else:
        for outer_pid in chain[chain.index(pid) + 1:]:
            if outer_pid not in processes:
                raise Unsupported("outer launcher is missing from foreground snapshot")
            outer_safe, outer_native = _outer_options(processes[outer_pid], kind, launcher)
            if outer_safe != safe or restart_options(kind, outer_native, cwd) != options:
                raise Unsupported("outer launcher does not explain the running configuration")
    result = {
        "agent": kind, "launcher": launcher, "cwd": cwd, "safehouse_args": safe,
        "agent_args": options, "launcher_pid": pid, "launcher_start": start,
        "origin": "recorded" if records else "reconstructed",
    }
    if (process_start(pid) != start or process_start(safehouse_pid) != safehouse_start
            or _socket_identity(socket_path) != socket_identity):
        raise Unsupported("launcher or Herdr socket changed while reading its recipe")
    return result


def get_launch(socket_path: str, agent_info: dict, process_info: dict, profile_bin: str) -> dict:
    try:
        return _get_launch(socket_path, agent_info, process_info, profile_bin)
    except Unsupported:
        raise
    except (OSError, ValueError, TypeError, KeyError) as exc:
        raise Unsupported("cannot validate launch metadata or process configuration") from exc
