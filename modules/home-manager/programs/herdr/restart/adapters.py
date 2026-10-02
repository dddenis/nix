"""Fail-closed adapters for local interactive agents (Python stdlib only)."""

import fcntl
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
import sys
import uuid


class Unsupported(ValueError):
    """A launch cannot be safely reproduced or stopped."""


KINDS = frozenset({"omp", "pi", "codex", "claude", "opencode"})
_COMMON_PI = "--provider --model --models --thinking --tools --session-dir --extension -e"
_VALUES = {
    "omp": set((_COMMON_PI + " --config --add-dir --smol --slow --service-tier --hook --trusted-extension --plugin-dir --skills --approval-mode --profile --system-prompt-template").split()),
    "pi": set((_COMMON_PI + " -t --exclude-tools -xt --skill --prompt-template --theme --name -n").split()),
    "codex": set("--config -c --enable --disable --model -m --local-provider --profile -p --sandbox -s --add-dir --ask-for-approval -a".split()),
    "claude": set("--model --fallback-model --effort --agent --settings --setting-sources --permission-mode --system-prompt-file --append-system-prompt-file --name -n".split()),
    "opencode": set("--model -m --agent --log-level".split()),
}
_BOOLEANS = {
    "omp": set("--no-tools --no-extensions --no-skills --no-prompt-templates --no-themes --no-title --no-rules --no-lsp --no-pty --allow-home --hide-thinking --verbose".split()),
    "pi": set("--no-tools -nt --no-builtin-tools -nbt --no-extensions -ne --no-skills -ns --no-prompt-templates -np --no-themes --no-context-files -nc --verbose --approve -a --no-approve -na --offline".split()),
    "codex": set("--oss --strict-config --approve-for-me --dangerously-bypass-hook-trust --search --no-alt-screen".split()),
    "claude": set("--verbose --strict-mcp-config --allow-dangerously-skip-permissions --disable-slash-commands --chrome --no-chrome --ide".split()),
    "opencode": {"--print-logs"},
}
_DEFAULTS = {"omp": set(), "pi": set(), "codex": {"--dangerously-bypass-approvals-and-sandbox", "--no-daemon"}, "claude": {"--dangerously-skip-permissions"}, "opencode": {"--auto"}}
_SELECTORS = {"omp": {"--resume", "-r", "--session"}, "pi": {"--session", "--session-id"}, "codex": set(), "claude": {"--resume", "-r", "--session-id"}, "opencode": {"--session", "-s"}}
_CONTINUE = {"omp": {"--continue", "-c"}, "pi": {"--continue", "-c", "--resume", "-r"}, "codex": {"--last", "--all"}, "claude": {"--continue", "-c"}, "opencode": {"--continue", "-c"}}
_SUBCOMMANDS = {
    "omp": set("agents auth auth-broker auth-gateway bench browser-relay classify collab config completion completions find gallery gc git grep images install login logout models plugin plugins predict ps read render setup shell skill skills ssh stats update usage web-search worker worktree".split()),
    "pi": set("install remove update list config".split()),
    "codex": set("agents exec e review login logout mcp plugin app-server remote-control app completion update doctor sandbox debug apply a queue archive delete migrate-rollouts unarchive fork cloud exec-server features help".split()),
    "claude": set("agents attach auth auto-mode daemon doctor install mcp plugin remote-control respawn rm self-hosted-runner setup-token stop kill update upgrade".split()),
    "opencode": set("acp agent attach auth completion debug export import mcp models pr run serve session stats upgrade uninstall web github".split()),
}


def _kind(kind):
    if kind not in KINDS:
        raise Unsupported("unsupported agent kind")


def _path(value, cwd):
    return os.path.realpath(os.path.join(cwd, os.path.expanduser(value)))


def restart_options(kind: str, argv: list[str], cwd: str) -> list[str]:
    """Keep allowlisted configuration, never a prompt, attachment, or selector.

    Inline credentials and inline system prompts are intentionally unsupported:
    persisting these in a restart recipe would store secrets. Use config files.
    Unknown extension flags fail closed rather than silently changing behavior.
    """
    _kind(kind)
    if not isinstance(argv, list) or any(not isinstance(x, str) or "\0" in x for x in argv):
        raise Unsupported("invalid argument vector")
    result = []
    i = 0
    positional = False
    resumed = False
    while i < len(argv):
        token = argv[i]
        i += 1
        if token == "--":
            break  # Everything remaining is positional input, never restart configuration.
        flag, equal, inline = token.partition("=")
        if not token.startswith("-"):
            if kind == "codex" and token == "resume" and not positional and not resumed:
                resumed = True
                if i < len(argv) and not argv[i].startswith("-"):
                    i += 1  # Old ID/name, not the authoritative durable reference.
                continue
            if not positional and token in _SUBCOMMANDS[kind]:
                raise Unsupported(f"{kind}: noninteractive or unsupported subcommand {token}")
            if kind == "opencode":
                if positional or _path(token, cwd) != os.path.realpath(cwd):
                    raise Unsupported("opencode: project argument does not match saved cwd")
            positional = True
            continue
        if flag in _DEFAULTS[kind] | _BOOLEANS[kind] | _CONTINUE[kind]:
            if equal:
                raise Unsupported(f"{kind}: unexpected value for {flag}")
            if flag in _BOOLEANS[kind]:
                result.append(flag)
            continue
        if flag in _SELECTORS[kind]:
            if not equal and i < len(argv) and not argv[i].startswith("-"):
                i += 1
            continue
        drop = flag in {"--image", "-i"} and kind == "codex" or flag == "--prompt" and kind == "opencode"
        directory = (kind == "omp" and flag == "--cwd") or (kind == "codex" and flag in {"-C", "--cd"})
        mode = kind in {"omp", "pi"} and flag == "--mode"
        # Claude's variadic flags are accepted only in = form: otherwise a trailing
        # prompt and a second config/dir value cannot be distinguished safely.
        variadic = kind == "claude" and flag in {"--add-dir", "--mcp-config", "--plugin-dir", "--allowedTools", "--allowed-tools", "--disallowedTools", "--disallowed-tools", "--tools"}
        if flag not in _VALUES[kind] and not (drop or directory or mode or variadic):
            raise Unsupported(f"{kind}: unsupported option {flag}")
        if equal:
            value = inline
        elif i < len(argv) and not argv[i].startswith("-"):
            value = argv[i]
            i += 1
        else:
            raise Unsupported(f"{kind}: missing value for {flag}")
        if not value:
            raise Unsupported(f"{kind}: empty value for {flag}")
        if kind == "codex" and flag in {"--config", "-c"}:
            key, separator, _ = value.partition("=")
            if not separator or not re.fullmatch(r"(?:model|model_provider|model_reasoning_effort|model_reasoning_summary|model_verbosity|sandbox_mode|approval_policy|features\.[A-Za-z0-9_]+|sandbox_workspace_write\.(?:writable_roots|network_access|exclude_tmpdir_env_var|exclude_slash_tmp))", key):
                raise Unsupported("codex: config override is not restart-safe; use a profile file")
        if flag in {"--settings", "--mcp-config"} and value.lstrip().startswith(("{", "[")):
            raise Unsupported(f"{kind}: inline configuration may contain secrets; use a file")
        if variadic and not equal and i < len(argv) and not argv[i].startswith("-"):
            raise Unsupported(f"claude: ambiguous variadic {flag}; use {flag}=value")
        if directory:
            if _path(value, cwd) != os.path.realpath(cwd):
                raise Unsupported(f"{kind}: launch directory differs from saved cwd")
        elif mode:
            if value != "text":
                raise Unsupported(f"{kind}: noninteractive mode")
        elif not drop:
            if variadic:
                result.append(f"{flag}={value}")
            else:
                result.extend((flag, value))
    return result


def _executable_kind(path):
    name = os.path.basename(path)
    if name in KINDS:
        return name
    if re.fullmatch(r"\.(omp|pi|codex|claude|opencode)-wrapped", name):
        return name[1:-8]
    return None


def _script_kind(path):
    normalized = path.replace("\\", "/")
    name = os.path.basename(normalized)
    if name in {"codex", "pi"} and normalized == os.path.expanduser(f"~/.cache/.bun/bin/{name}"):
        return name
    if "/@openai/codex/" in normalized and normalized.endswith("/bin/codex.js"):
        return "codex"
    if "/@anthropic-ai/claude-code/" in normalized and normalized.endswith("/cli.js"):
        return "claude"
    if "pi-coding-agent" in normalized and normalized.endswith("/dist/cli.js"):
        return "pi"
    if normalized.endswith("/coding-agent/src/cli.ts") or normalized.endswith("/coding-agent/dist/cli.js"):
        return "omp"
    return None


def agent_process(kind: str, process_info: dict) -> dict:
    """Select one actual foreground writer; only recognize known entry points."""
    _kind(kind)
    candidates = []
    for process in process_info.get("foreground_processes", []):
        argv = process.get("argv")
        if not isinstance(argv, list) or not argv or any(not isinstance(x, str) for x in argv):
            continue
        found = _executable_kind(argv[0])
        offset = 1
        interpreter = os.path.basename(argv[0]) in {"node", "bun", "bunx"}
        if interpreter:
            if len(argv) < 2:
                continue
            found = _script_kind(argv[1])
            offset = 2
        if found is None:
            continue
        if found != kind:
            raise Unsupported("multiple agent kinds in foreground process group")
        if not isinstance(process.get("pid"), int) or process["pid"] <= 0:
            raise Unsupported("agent process has no valid PID")
        args = argv[offset:]
        restart_options(kind, args, process.get("cwd") or "/")
        candidates.append((process, args, interpreter))
    # The official Codex JS launcher waits for its native child. It is not a
    # second interactive writer; require identical args to prove that relation.
    if kind == "codex" and len(candidates) == 2:
        native = [x for x in candidates if not x[2]]
        node = [x for x in candidates if x[2]]
        if len(native) == len(node) == 1 and native[0][1] == node[0][1]:
            candidates = native
    if len(candidates) != 1:
        raise Unsupported("no unique supported foreground agent process")
    process, args, _ = candidates[0]
    return {**process, "agent_args": args}


def session_header(kind: str, path: str) -> dict:
    """Read the durable identity, including OMP's optional leading title slot."""
    try:
        if not stat.S_ISREG(os.stat(path).st_mode):
            raise Unsupported("session is not a regular file")
        with open(path, encoding="utf-8") as stream:
            def record():
                line = stream.readline(1024 * 1024 + 1)
                if len(line) > 1024 * 1024:
                    raise Unsupported("session header is too large")
                return json.loads(line)

            header = record()
            # OMP session-title-slot.ts puts a mutable title record before the
            # immutable session header. Do not scan arbitrary transcript entries.
            if kind == "omp" and isinstance(header, dict) and header.get("type") == "title" and header.get("v") == 1:
                header = record()
    except (OSError, UnicodeError, ValueError) as exc:
        raise Unsupported(f"{kind}: unreadable or invalid session header") from exc
    if not isinstance(header, dict) or header.get("type") != "session" or not isinstance(header.get("id"), str) or not header["id"]:
        raise Unsupported(f"{kind}: missing session header identity")
    if not isinstance(header.get("cwd"), str) or not os.path.isabs(header["cwd"]):
        raise Unsupported(f"{kind}: session header has no absolute working directory")
    return header


def resume_arguments(kind: str, reference: dict, cwd: str) -> list[str]:
    _kind(kind)
    if not isinstance(reference, dict) or reference.get("agent", kind) != kind:
        raise Unsupported("session reference belongs to another agent")
    value = reference.get("value")
    if not isinstance(value, str) or not value or "\0" in value:
        raise Unsupported("missing exact durable session reference")
    if kind in {"omp", "pi"}:
        if reference.get("kind") != "path" or not os.path.isabs(value):
            raise Unsupported(f"{kind}: requires an absolute session file path")
        header = session_header(kind, value)
        saved_cwd = header["cwd"]
        if not isinstance(saved_cwd, str) or not os.path.isabs(saved_cwd) or os.path.realpath(saved_cwd) != os.path.realpath(cwd):
            raise Unsupported(f"{kind}: session cwd does not match pane cwd")
        return ["--session", value]
    if reference.get("kind") != "id":
        raise Unsupported(f"{kind}: requires an exact session ID")
    if kind in {"codex", "claude"}:
        try:
            if str(uuid.UUID(value)) != value.lower():
                raise ValueError("not a canonical UUID")
        except ValueError as exc:
            raise Unsupported(f"{kind}: session ID must be a full UUID") from exc
        return ["resume", value, "-C", cwd] if kind == "codex" else ["--resume", value]
    if not re.fullmatch(r"ses_[A-Za-z0-9]+", value):
        raise Unsupported("opencode: invalid session ID")
    return ["--session", value]


def codex_writer_owns_session(pid: int, session_id: str, lsof: str) -> bool:
    """Prove native writer ownership without triggering Codex's deferred hooks."""
    # Codex queues SessionStart until a model turn, including after resume.
    # Its live recorder instead holds an exclusive, per-thread file lock:
    # https://github.com/openai/codex/blob/rust-v0.159.2/codex-rs/rollout/src/writer_lock.rs
    filename = f"{uuid.UUID(session_id)}.lock"

    def inspect(*args):
        result = subprocess.run(
            [lsof, "-nP", *args], stdin=subprocess.DEVNULL,
            capture_output=True, text=True, timeout=3,
        )
        if result.returncode not in (0, 1):
            raise Unsupported(f"Codex writer inspection failed: lsof exit {result.returncode}")
        return result.stdout if result.returncode == 0 else ""

    paths = {
        Path(line[1:])
        for line in inspect("-a", "-p", str(pid), "-Fn").splitlines()
        if line.startswith("n/")
        and Path(line[1:]).name == filename
        and Path(line[1:]).parent.name == "thread-writer-locks"
    }
    if len(paths) != 1:
        return False
    path = paths.pop()

    def exclusively_locked(file, fields):
        if sys.platform == "darwin":
            # Darwin's struct flock: off_t start/len, pid_t, short type/whence.
            # F_GETLK reports flock ownership as pid -1. Unlike trying a shared
            # lock, this query cannot race with and block a starting writer.
            query = struct.pack("qqihh", 0, 0, 0, fcntl.F_WRLCK, os.SEEK_SET)
            start, length, owner, kind, _ = struct.unpack(
                "qqihh", fcntl.fcntl(file, fcntl.F_GETLK, query),
            )
            return owner == -1 and kind == fcntl.F_WRLCK and start == 0 and length == 0
        # Linux lsof exposes a whole-file exclusive lock as W (not partial w).
        return "lW" in fields

    try:
        with path.open("rb") as file:
            info = os.fstat(file.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                return False
            # macOS cannot name flock owners. Exclude every other opener;
            # our descriptor is read-only and never acquires a lock.
            fields = inspect("-Fpfl", "--", str(path)).splitlines()
            owners = {
                int(line[1:])
                for line in fields
                if line.startswith("p")
            }
            current = path.stat()
            return (
                owners == {pid, os.getpid()}
                and (current.st_dev, current.st_ino) == (info.st_dev, info.st_ino)
                and exclusively_locked(file, fields)
            )
    except FileNotFoundError:
        return False


def shutdown_keys(kind: str) -> list[str] | None:
    _kind(kind)
    # OMP interactive-mode.ts createSessionTeardown persists drafts and disposes
    # on SIGTERM. Pi 0.82.1 interactive-mode.js registerSignalHandlers invokes
    # shutdown({fromSignal:true}), emitting session_shutdown before tty cleanup.
    if kind in {"omp", "pi"}:
        return None
    # Codex: codex-rs/tui/src/chatwidget.rs request_quit_without_confirmation
    # routes double Ctrl+C to ExitMode::ShutdownFirst (not an immediate exit).
    # https://github.com/openai/codex/blob/main/codex-rs/tui/src/chatwidget.rs
    # Claude documents first Ctrl+C clearing draft and second exiting:
    # https://code.claude.com/docs/en/interactive-mode
    # No Enter or slash command is ever sent. Custom bindings can prevent exit;
    # the caller must time out without force-killing or starting another writer.
    if kind in {"codex", "claude"}:
        return ["ctrl+c", "ctrl+c"]
    # https://opencode.ai/docs/keybinds/: app_exit includes <leader>q,
    # default leader Ctrl+X. Unlike Ctrl+D this does not delete draft characters.
    return ["ctrl+x", "q"]
