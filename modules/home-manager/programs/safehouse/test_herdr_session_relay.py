import importlib.util
import json
import os
from pathlib import Path
import socket
import tempfile
import threading
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "herdr_session_relay", Path(__file__).with_name("herdr-session-relay.py"))
relay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relay)

PANE = "w1:p1"
SESSION = "3557d52e-6362-4a1b-b853-a5eb7f53586c"
CLAUDE_TRANSCRIPT = str(Path.home() / ".claude/projects/-Users-ddd-dev" / f"{SESSION}.jsonl")
OMP_SESSION = str(Path.home() / ".omp/agent/sessions/-dev-x" / f"2026-10-17T10-00-00-000Z_{SESSION}.jsonl")


def request(method, agent, **params):
    return {"id": "client:1", "method": method, "params": {
        "pane_id": PANE, "source": f"herdr:{agent}", "agent": agent, "seq": 1, **params}}


class RelayValidationTests(unittest.TestCase):
    def test_claude_session_report_keeps_transcript_path(self):
        _, method, report = relay.validated_report(request(
            "pane.report_agent_session", "claude", agent_session_id=SESSION,
            agent_session_path=CLAUDE_TRANSCRIPT, session_start_source="fork",
        ), "claude", PANE)
        self.assertEqual(method, "pane.report_agent_session")
        self.assertEqual(report, {
            "pane_id": PANE, "agent": "claude", "source": "herdr:claude",
            "agent_session_id": SESSION, "agent_session_path": CLAUDE_TRANSCRIPT,
            "session_start_source": "fork",
        })

    def test_omp_session_switch_reports_session_file(self):
        _, _, report = relay.validated_report(request(
            "pane.report_agent_session", "omp", agent_session_path=OMP_SESSION,
            session_start_source="new",
        ), "omp", PANE)
        self.assertEqual(report["agent_session_path"], OMP_SESSION)
        self.assertNotIn("agent_session_id", report)

    def test_session_path_outside_agent_state_is_rejected(self):
        home = Path.home()
        cases = [
            ("claude", "/tmp/x/transcript.jsonl"),
            ("claude", str(home / ".claude/projects/a/../../settings.jsonl")),
            ("claude", str(home / ".claude/projects/a/b/nested.jsonl")),
            ("claude", str(home / ".claude/projects/a/transcript.json")),
            ("claude", OMP_SESSION),
            ("omp", CLAUDE_TRANSCRIPT),
            ("codex", str(home / ".codex/sessions/2026/rollout.jsonl")),
        ]
        for agent, path in cases:
            with self.subTest(agent=agent, path=path), self.assertRaises(ValueError):
                relay.validated_report(request(
                    "pane.report_agent_session", agent, agent_session_id=SESSION,
                    agent_session_path=path,
                ), agent, PANE)

    def test_resume_command_is_never_accepted(self):
        for agent in relay.AGENTS:
            with self.subTest(agent=agent), self.assertRaises(ValueError):
                relay.validated_report(request(
                    "pane.report_agent_session", agent, agent_session_id=SESSION,
                    resume_argv=["sh", "-c", "touch /tmp/escaped"],
                ), agent, PANE)

    def test_agent_may_only_report_as_itself(self):
        with self.assertRaises(ValueError):
            relay.validated_report(request(
                "pane.report_agent_session", "codex", agent_session_id=SESSION,
            ), "claude", PANE)

    def test_only_omp_reports_lifecycle_state(self):
        _, method, report = relay.validated_report(request(
            "pane.report_agent", "omp", state="working", agent_session_path=OMP_SESSION,
        ), "omp", PANE)
        self.assertEqual(method, "pane.report_agent")
        self.assertEqual(report, {
            "pane_id": PANE, "agent": "omp", "source": "herdr:omp",
            "state": "working", "agent_session_path": OMP_SESSION,
        })
        for agent in ("codex", "claude"):
            with self.subTest(agent=agent), self.assertRaises(ValueError):
                relay.validated_report(request("pane.report_agent", agent, state="idle"), agent, PANE)

    def test_omp_state_message_cannot_carry_terminal_controls(self):
        _, _, report = relay.validated_report(request(
            "pane.report_agent", "omp", state="blocked", message="Continue?\n\x1b]0;x\x07",
        ), "omp", PANE)
        self.assertEqual(report["message"], "Continue?  ]0;x ")

    def test_unknown_lifecycle_state_is_rejected(self):
        with self.assertRaises(ValueError):
            relay.validated_report(request("pane.report_agent", "omp", state="done"), "omp", PANE)


class RelayLaunchTests(unittest.TestCase):
    def test_unknown_agent_is_rejected(self):
        with patch("sys.argv", ["relay", "opencode", "/usr/bin/true"]), \
                patch.object(relay.os, "execv") as execv, self.assertRaises(ValueError):
            relay.main()
        execv.assert_not_called()

    def test_without_herdr_runs_command_directly(self):
        # A successful exec never returns into the relay.
        with patch("sys.argv", ["relay", "claude", "/usr/bin/true", "--"]), \
                patch.dict(os.environ, {"HERDR_ENV": ""}), \
                patch.object(relay.os, "execv", side_effect=SystemExit) as execv, \
                self.assertRaises(SystemExit):
            relay.main()
        execv.assert_called_once_with("/usr/bin/true", ["/usr/bin/true", "--"])

    def test_forwards_requested_method_with_relay_sequence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "herdr.sock"
            received = []
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                server.bind(str(path))
                server.listen(1)

                def serve():
                    connection, _ = server.accept()
                    with connection:
                        message = relay.read_message(connection)
                        received.append(message)
                        connection.sendall(json.dumps({"id": message["id"], "result": {}}).encode() + b"\n")

                thread = threading.Thread(target=serve)
                thread.start()
                relay.forward_report(path, relay.socket_identity(path), "pane.report_agent",
                                     {"pane_id": PANE, "agent": "omp", "source": "herdr:omp", "state": "idle"}, 7)
                thread.join(2)
        self.assertEqual(received[0]["method"], "pane.report_agent")
        self.assertEqual(received[0]["params"], {
            "pane_id": PANE, "agent": "omp", "source": "herdr:omp", "state": "idle", "seq": 7})


if __name__ == "__main__":
    unittest.main()
