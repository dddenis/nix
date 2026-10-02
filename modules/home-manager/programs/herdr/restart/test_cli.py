import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import cli
from adapters import Unsupported


class Pane:
    name = "test"
    socket_path = "/test/herdr.sock"

    def __init__(self, agent, process):
        self.current = copy.deepcopy(agent)
        self.process = process
        self.at_shell = False
        self.commands = []

    def agent(self, pane):
        if self.at_shell:
            raise cli.ControlError("agent is gone", "agent_not_found")
        return self.current

    def pane(self, pane):
        return self.current

    def processes(self, pane):
        return {
            "shell_pid": 101,
            "foreground_process_group_id": 101 if self.at_shell else 102,
            "foreground_processes": [{"pid": 101}] if self.at_shell else [self.process],
        }

    def call(self, *args, expect_json=True):
        self.commands.append(args)


class RestartSafety(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.cwd = str(Path(self.directory.name).resolve())
        self.session = Path(self.cwd) / "conversation.jsonl"
        self.session.write_text(json.dumps({"type": "session", "id": "conversation-a", "cwd": self.cwd}) + "\n")
        self.reference = {"agent": "omp", "kind": "path", "value": str(self.session)}
        self.agent = {
            "pane_id": "w1:p1", "terminal_id": "terminal-a", "agent": "omp",
            "agent_status": "idle", "agent_session": self.reference, "state_change_seq": 12,
        }
        self.process = {"pid": 102, "argv": ["/nix/store/old/bin/omp"], "name": "omp", "cwd": self.cwd}
        self.client = Pane(self.agent, self.process)
        launch = {
            "launcher": "/home/test/.nix-profile/bin/omp", "cwd": self.cwd,
            "safehouse_args": [], "agent_args": [], "launcher_pid": 102,
            "launcher_start": "original-start", "origin": "recorded",
        }
        self.plan = cli.Plan(
            self.client, self.agent, self.process, "original-start", launch,
            self.reference, ("conversation-a", self.cwd), None,
            [launch["launcher"], "--session", str(self.session)], 101,
        )
        self.addCleanup(patch.stopall)
        patch("cli.process_start", return_value="original-start").start()
        patch("cli.preflight").start()
        self.kill = patch("cli.os.kill").start()

    def assert_not_stopped(self):
        self.kill.assert_not_called()
        self.assertEqual(self.client.commands, [])

    def test_agent_becoming_busy_is_not_stopped(self):
        self.client.current["agent_status"] = "working"
        with self.assertRaises(Unsupported):
            cli.restart(self.plan, 1)
        self.assert_not_stopped()

    def test_idle_agent_switching_conversation_is_not_stopped(self):
        self.client.current["agent_session"]["value"] = "/different/session.jsonl"
        with self.assertRaises(Unsupported):
            cli.restart(self.plan, 1)
        self.assert_not_stopped()

    def test_replaced_process_is_not_stopped_even_with_same_agent_metadata(self):
        self.client.process = {**self.process, "pid": 103}
        with self.assertRaises(Unsupported):
            cli.restart(self.plan, 1)
        self.assert_not_stopped()

    def test_reused_pid_with_different_start_time_is_not_stopped(self):
        with patch("cli.process_start", return_value="new-start"):
            with self.assertRaises(Unsupported):
                cli.restart(self.plan, 1)
        self.assert_not_stopped()

    def test_shutdown_timeout_never_launches_second_writer_or_force_kills(self):
        clock = [0.0]

        def advance(seconds):
            clock[0] += seconds

        with patch("cli.time.monotonic", side_effect=lambda: clock[0]), patch("cli.time.sleep", side_effect=advance):
            with self.assertRaisesRegex(cli.ControlError, "no force kill attempted"):
                cli.restart(self.plan, 0.4)
        signals = [call.args[1] for call in self.kill.call_args_list if call.args[1] != 0]
        self.assertEqual(signals, [cli.signal.SIGTERM])
        self.assertEqual(self.client.commands, [])

    def test_session_disappearing_at_shutdown_is_not_recreated_by_resume(self):
        def stop(pid, sig):
            if sig == cli.signal.SIGTERM:
                self.session.unlink()
                self.client.at_shell = True
            else:
                raise ProcessLookupError

        self.kill.side_effect = stop
        with self.assertRaisesRegex(cli.ControlError, "unreadable or invalid session header"):
            cli.restart(self.plan, 1)
        self.assertEqual(self.client.commands, [])
        self.assertFalse(self.session.exists())

    def test_cached_old_agent_metadata_prevents_shell_reuse(self):
        self.client.at_shell = True
        self.kill.side_effect = ProcessLookupError
        with patch.object(self.client, "agent", return_value=self.agent):
            self.assertFalse(cli.shell_ready(self.plan))
        self.assertTrue(cli.shell_ready(self.plan))

    def test_terminal_replacement_aborts_without_sending_launch_command(self):
        def stop(pid, sig):
            self.client.current["terminal_id"] = "different-terminal"

        self.kill.side_effect = stop
        with self.assertRaisesRegex(cli.ControlError, "terminal was replaced"):
            cli.restart(self.plan, 1)
        self.assertEqual(self.client.commands, [])

    def test_startup_with_wrong_conversation_is_not_reported_as_success(self):
        self.client.current["agent_session"]["value"] = "/different/session.jsonl"
        with self.assertRaisesRegex(cli.ControlError, "different conversation"):
            cli.resumed_agent(self.plan)

    def test_same_file_path_with_new_session_identity_is_not_accepted(self):
        self.session.write_text(json.dumps({"type": "session", "id": "conversation-b", "cwd": self.cwd}) + "\n")
        with self.assertRaisesRegex(Unsupported, "saved conversation changed"):
            cli.assert_unchanged(self.plan)
        self.assert_not_stopped()

    def test_resumed_conversation_in_different_directory_is_rejected(self):
        self.client.process = {**self.process, "pid": 103, "cwd": "/different"}
        with self.assertRaisesRegex(cli.ControlError, "different working directory"):
            cli.resumed_agent(self.plan)

    def test_codex_pid_reuse_during_native_verification_never_reports_identity(self):
        reference = {"agent": "codex", "kind": "id", "value": "01234567-89ab-4cde-8fab-0123456789ab"}
        self.agent.update(agent="codex", agent_session=reference)
        self.plan.reference = reference
        self.plan.conversation = cli.reference_key(reference)
        self.client.current = {**self.agent, "agent_session": None}
        self.client.process = {"pid": 103, "argv": ["/bin/codex"], "name": "codex", "cwd": self.cwd}
        self.client.lsof = "lsof"
        with patch("cli.codex_writer_owns_session", return_value=True), patch("cli.process_start", side_effect=["first-process", "reused-pid"]):
            with self.assertRaisesRegex(cli.ControlError, "process changed"):
                cli.resumed_agent(self.plan)
        self.assertEqual(self.client.commands, [])


if __name__ == "__main__":
    unittest.main()
