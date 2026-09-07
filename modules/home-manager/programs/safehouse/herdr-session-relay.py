"""Run Safehouse with a Herdr session-report relay bound to one Codex pane."""

import json
import os
from pathlib import Path
import re
import select
import signal
import socket
import stat
import sys
import tempfile
import time
import uuid


MAX_MESSAGE_BYTES = 4096
IO_TIMEOUT = 0.3
POLL_INTERVAL = 0.1
SESSION_SOURCES = {"startup", "resume", "clear", "compact"}
REPORT_FIELDS = {
    "pane_id", "source", "agent", "agent_session_id", "seq",
    "session_start_source",
}


def socket_identity(path):
    info = path.stat()
    if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
        raise ValueError("Herdr socket must belong to the current user")
    return info.st_dev, info.st_ino


def read_message(connection):
    deadline = time.monotonic() + IO_TIMEOUT
    message = bytearray()
    while len(message) <= MAX_MESSAGE_BYTES:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("request timed out")
        connection.settimeout(remaining)
        chunk = connection.recv(MAX_MESSAGE_BYTES + 1 - len(message))
        if not chunk:
            raise ValueError("incomplete request")
        message.extend(chunk)
        if b"\n" in message:
            line, trailing = message.split(b"\n", 1)
            if trailing.strip() or len(message) > MAX_MESSAGE_BYTES:
                raise ValueError("expected one bounded JSON request")
            return json.loads(line)
    raise ValueError("request too large")


def validated_report(request, pane_id):
    if not isinstance(request, dict) or set(request) - {"id", "method", "params"}:
        raise ValueError("invalid request")
    request_id = request.get("id")
    if not isinstance(request_id, str) or len(request_id) > 128:
        raise ValueError("invalid request ID")
    if request.get("method") != "pane.report_agent_session":
        raise ValueError("only Codex session reports are allowed")
    params = request.get("params")
    if not isinstance(params, dict) or set(params) - REPORT_FIELDS:
        raise ValueError("invalid session report")
    if (
        params.get("pane_id") != pane_id
        or params.get("agent") != "codex"
        or params.get("source") != "herdr:codex"
    ):
        raise ValueError("session report does not match this Codex pane")
    session_id = params.get("agent_session_id")
    if not isinstance(session_id, str) or len(session_id) != 36:
        raise ValueError("invalid Codex session ID")
    if str(uuid.UUID(session_id)) != session_id:
        raise ValueError("expected a canonical Codex session UUID")
    source = params.get("session_start_source")
    if source is not None and (
        not isinstance(source, str) or source not in SESSION_SOURCES
    ):
        raise ValueError("invalid session start source")
    # Build a new request: never forward a client-selected method, path or seq.
    report = {
        "pane_id": pane_id,
        "agent": "codex",
        "source": "herdr:codex",
        "agent_session_id": session_id,
    }
    if source is not None:
        report["session_start_source"] = source
    return request_id, report


def forward_report(upstream_path, upstream_identity, report, sequence):
    # A relay for the old server must not register against a replacement server.
    if socket_identity(upstream_path) != upstream_identity:
        raise ValueError("Herdr server socket changed; relaunch Codex")
    request_id = f"herdr-session-relay:{sequence}"
    request = {
        "id": request_id,
        "method": "pane.report_agent_session",
        "params": {**report, "seq": sequence},
    }
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as upstream:
        upstream.settimeout(IO_TIMEOUT)
        upstream.connect(str(upstream_path))
        if socket_identity(upstream_path) != upstream_identity:
            raise ValueError("Herdr server socket changed; relaunch Codex")
        upstream.sendall(json.dumps(request).encode() + b"\n")
        response = read_message(upstream)
    if (
        not isinstance(response, dict)
        or response.get("id") != request_id
        or "error" in response
        or "result" not in response
    ):
        raise ValueError("Herdr did not accept the session report")


def policy_text(relay_root, launch_dir, relay_socket, upstream_socket):
    def quoted(path):
        text = str(path)
        if any(ord(character) < 32 or ord(character) == 127 for character in text):
            raise ValueError("control characters are not allowed in socket paths")
        return json.dumps(text, ensure_ascii=False)

    return f""";; Only this launch's relay may be contacted; its files stay immutable.
(deny file-read* file-write* (subpath {quoted(relay_root)}))
(allow file-read* (literal {quoted(relay_root)}) (subpath {quoted(launch_dir)}))
(deny network-outbound
    (remote unix-socket (path-regex #"^(/private)?/tmp/herdr-session-relays-[0-9]+/")))
(allow network-outbound
    (remote unix-socket (path-literal {quoted(relay_socket)})))
;; Keep the full Herdr control API blocked even with broader user profiles.
(deny network-outbound
    (remote unix-socket (path-literal {quoted(upstream_socket)})))
"""


def run_relay(command, pane_id, upstream_path):
    upstream_identity = socket_identity(upstream_path)
    # Keep Unix socket paths below macOS's 104-byte limit. This parent is shared
    # across launches so every relay policy protects every relay's files.
    relay_root = Path("/private/tmp") / f"herdr-session-relays-{os.getuid()}"
    relay_root.mkdir(mode=0o700, exist_ok=True)
    root_info = relay_root.lstat()
    if (
        not stat.S_ISDIR(root_info.st_mode)
        or root_info.st_uid != os.getuid()
        or stat.S_IMODE(root_info.st_mode) != 0o700
    ):
        raise ValueError("relay directory must be a private directory owned by this user")

    with tempfile.TemporaryDirectory(prefix="pane-", dir=relay_root) as directory:
        launch_dir = Path(directory)
        relay_socket = launch_dir / "report.sock"
        profile = launch_dir / "relay.sb"
        profile.write_text(
            policy_text(relay_root, launch_dir, relay_socket, upstream_path),
            encoding="utf-8",
        )
        separator = command.index("--")
        sandbox_command = [
            *command[:separator],
            f"--append-profile={profile}",
            "--",
            "HERDR_ENV=1",
            f"HERDR_PANE_ID={pane_id}",
            f"HERDR_SOCKET_PATH={relay_socket}",
            *command[separator + 1:],
        ]
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            listener.bind(str(relay_socket))
            os.chmod(relay_socket, 0o600)
            listener.listen(8)
            listener.settimeout(POLL_INTERVAL)
            owner_pid = os.getpid()
            ready_read, ready_write = os.pipe()
            relay_pid = os.fork()
            if relay_pid:
                os.close(ready_write)
                listener.close()
                try:
                    if not select.select([ready_read], [], [], 2)[0]:
                        raise ValueError("session relay did not start")
                    if os.read(ready_read, 1) != b"1":
                        raise ValueError("session relay failed to start")
                    os.close(ready_read)
                    # Preserve Safehouse's original PID, process group, terminal
                    # handling and exit status; no intermediate supervisor waits
                    # on its Bash wrapper or forwards signals to the wrong PID.
                    os.execv(sandbox_command[0], sandbox_command)
                finally:
                    # Successful exec never reaches here. The helper owns normal
                    # cleanup after Safehouse finishes waiting for Codex to exit.
                    try:
                        os.kill(relay_pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    os.waitpid(relay_pid, 0)

            os.close(ready_read)
            os.setsid()
            # The helper must neither receive terminal Ctrl-C nor keep the pane's
            # terminal open. It exits when its original launcher parent exits;
            # getppid also avoids confusing a reused PID with that launcher.
            with open(os.devnull, "r+b", buffering=0) as devnull:
                for descriptor in (0, 1, 2):
                    os.dup2(devnull.fileno(), descriptor)
            stopping = False

            def stop(_signum, _frame):
                nonlocal stopping
                stopping = True

            for signum in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
                signal.signal(signum, stop)
            os.write(ready_write, b"1")
            os.close(ready_write)
            sequence = time.time_ns()
            last_report = None
            # Bound even valid, changing reports from an untrusted caller.
            tokens = 4.0
            refill_at = time.monotonic()
            while not stopping and os.getppid() == owner_pid:
                try:
                    connection, _ = listener.accept()
                except socket.timeout:
                    continue
                with connection:
                    request_id = None
                    try:
                        request = read_message(connection)
                        request_id, report = validated_report(request, pane_id)
                        if stopping or os.getppid() != owner_pid:
                            break
                        if report != last_report:
                            now = time.monotonic()
                            tokens = min(4.0, tokens + now - refill_at)
                            refill_at = now
                            if tokens < 1:
                                raise ValueError("session report rate limit exceeded")
                            tokens -= 1
                            sequence = max(sequence + 1, time.time_ns())
                            forward_report(upstream_path, upstream_identity, report, sequence)
                            last_report = report
                        response = {"id": request_id, "result": {"type": "ok"}}
                    except (OSError, ValueError, RecursionError):
                        response = {
                            "id": request_id,
                            "error": {
                                "code": "session_report_rejected",
                                "message": "Session report rejected or Herdr unavailable",
                            },
                        }
                    try:
                        connection.settimeout(IO_TIMEOUT)
                        connection.sendall(json.dumps(response).encode() + b"\n")
                    except OSError:
                        pass
            return 0


def main():
    command = sys.argv[1:]
    if not command:
        raise ValueError("expected the Safehouse command")
    if os.environ.get("HERDR_ENV") != "1":
        os.execv(command[0], command)
    pane_id = os.environ.get("HERDR_PANE_ID", "")
    socket_path = os.environ.get("HERDR_SOCKET_PATH", "")
    if not re.fullmatch(r"w[0-9A-Za-z]+:p[0-9A-Za-z]+", pane_id) or not socket_path:
        raise ValueError("Herdr pane identity or socket path is missing")
    return run_relay(command, pane_id, Path(socket_path).resolve(strict=True))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"herdr-session-relay: {error}", file=sys.stderr)
        sys.exit(1)
