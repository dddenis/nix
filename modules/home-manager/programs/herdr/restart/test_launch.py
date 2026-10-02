import copy
import json
import os
from pathlib import Path
import socket
import tempfile
import unittest
from unittest.mock import patch

import launch
from adapters import Unsupported


HASH = "a" * 32
BASH = f"/nix/store/{HASH}-bash-5/bin/bash"
SAFEHOUSE = f"/nix/store/{HASH}-agent-safehouse-0.12.0/bin/safehouse"
OMP = f"/nix/store/{HASH}-omp-18.4.4/bin/omp"


class LaunchSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.environment = patch.dict(os.environ, {
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "APP_SANDBOX_CONTAINER_ID": "", "AGENT_BROWSER_ARGS": "",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.socket_path = str(self.root / "herdr.sock")
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.bind(self.socket_path)
        self.addCleanup(self.socket.close)
        self.profile = str(Path.home() / ".nix-profile/bin")
        self.cwd = str(self.root)
        self.agent = {"agent": "omp", "pane_id": "w1:p1"}
        self.info = {
            "pane_id": "w1:p1", "shell_pid": 10,
            "foreground_process_group_id": 20,
            "foreground_processes": [
                {"pid": 30, "name": "omp", "argv": [OMP], "cwd": self.cwd},
                {"pid": 20, "name": "bash", "cwd": self.cwd,
                 "argv": [BASH, SAFEHOUSE,
                          "--append-profile=" + str(self.root / "config/safehouse/nix.sb"),
                          "--enable=agent-browser", "--enable=clipboard", "--enable=keychain",
                          "--enable=process-control", "--env-pass=TMUX,TMUX_PANE",
                          "--enable=microphone",
                          "--append-profile=" + str(self.root / "config/safehouse/omp.sb"),
                          "--enable=docker", "--env=./.env", "--",
                          "AGENT_BROWSER_ARGS=--no-sandbox", OMP]},
            ],
        }
        self.ps = patch.object(launch, "_ps", side_effect=self.process_field)
        self.ps.start()
        self.addCleanup(self.ps.stop)

    def process_field(self, pid, field):
        return "Tue Sep 29 12:00:00 2026" if field == "lstart" else str({30: 20, 20: 10}[pid])

    def recipe(self):
        return launch.get_launch(self.socket_path, self.agent, self.info, self.profile)

    def record(self, *args):
        with patch.dict(os.environ, {"HERDR_SOCKET_PATH": self.socket_path, "HERDR_PANE_ID": "w1:p1"}), \
                patch.object(os, "getppid", return_value=20), patch.object(os, "getcwd", return_value=self.cwd):
            launch.record_main(["omp", self.profile + "/omp", "20", "--", *args])
        return launch._directory(self.socket_path) / "20.json"

    def test_legacy_preserves_project_options_without_replaying_prompt(self):
        self.info["foreground_processes"][0]["argv"].extend(["do not replay this prompt"])
        self.info["foreground_processes"][1]["argv"].extend(["do not replay this prompt"])
        recipe = self.recipe()
        self.assertEqual(recipe["safehouse_args"], ["--enable=docker", "--env=./.env"])
        self.assertEqual(recipe["agent_args"], [])
        self.assertEqual(recipe["launcher"], self.profile + "/omp")
        self.assertEqual(recipe["cwd"], self.cwd)
        self.assertFalse(launch.state_root().exists())

    def test_recorded_unknown_option_blocks_legacy_fallback_without_storing_secret(self):
        path = self.record("--safehouse", "--enable=docker", "--env=./.env", "--", "--unknown-option=SECRET")
        text = path.read_text()
        self.assertNotIn("SECRET", text)
        self.assertNotIn("--unknown-option", text)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        with self.assertRaisesRegex(Unsupported, "recorded as unsupported"):
            self.recipe()

    def test_recorded_identity_mismatch_never_falls_back(self):
        path = self.record("--safehouse", "--enable=docker", "--env=./.env", "--")
        original = json.loads(path.read_text())
        for field, value in (("launcher_start", "older process"), ("pane_id", "w9:p9"),
                             ("socket_identity", [0, 0]), ("launcher_pid", 99)):
            with self.subTest(field=field):
                path.write_text(json.dumps({**original, field: value}))
                with self.assertRaisesRegex(Unsupported, "metadata does not match"):
                    self.recipe()

    def test_recorded_boundary_explains_unknown_outer_wrapper(self):
        path = self.record("--safehouse", "--enable=docker", "--env=./.env", "--")
        self.info["foreground_processes"].append({
            "pid": 15, "name": "bash", "cwd": self.cwd,
            "argv": [BASH, str(self.root / "project-wrapper")],
        })
        with patch.object(launch, "_ancestry", return_value=[30, 20, 15]):
            recipe = self.recipe()
            self.assertEqual(recipe["origin"], "recorded")
            self.assertEqual(recipe["launcher_pid"], 20)
            self.assertEqual(recipe["safehouse_args"], ["--enable=docker", "--env=./.env"])
            path.unlink()
            with self.assertRaisesRegex(Unsupported, "unrecognized outer launcher"):
                self.recipe()

    def test_replaced_socket_invalidates_record(self):
        self.record("--safehouse", "--enable=docker", "--env=./.env", "--")
        os.unlink(self.socket_path)
        replacement = socket.socket(socket.AF_UNIX)
        self.addCleanup(replacement.close)
        replacement.bind(self.socket_path)
        with self.assertRaisesRegex(Unsupported, "metadata does not match"):
            self.recipe()

    def test_unknown_safehouse_environment_is_not_silently_lost(self):
        argv = self.info["foreground_processes"][1]["argv"]
        argv.insert(argv.index("--") + 1, "CUSTOM_TOKEN=secret")
        with self.assertRaisesRegex(Unsupported, "command environment"):
            self.recipe()

    def test_ambiguous_safehouse_ancestry_is_rejected(self):
        extra = copy.deepcopy(self.info["foreground_processes"][1])
        extra["pid"] = 25
        self.info["foreground_processes"].append(extra)
        with patch.object(launch, "_ancestry", return_value=[30, 25, 20]):
            with self.assertRaisesRegex(Unsupported, "exactly one Safehouse"):
                self.recipe()

    def test_nested_sandbox_does_not_record_launch(self):
        with patch.dict(os.environ, {"APP_SANDBOX_CONTAINER_ID": "agent-safehouse"}):
            self.record("--safehouse", "--enable=docker", "--env=./.env", "--")
        self.assertFalse(launch.state_root().exists())

    def test_outer_script_environment_and_shell_expansion_are_rejected(self):
        process = {"argv": [BASH, f"/nix/store/{HASH}-omp-script"]}
        scripts = [
            'export TOKEN=secret\nexec "$HOME/.nix-profile/bin/omp" "$@"',
            'exec "$HOME/.nix-profile/bin/omp" --safehouse --env=$(printenv TOKEN) -- "$@"',
            'exec "$HOME/.nix-profile/bin/omp" $@',
        ]
        for text in scripts:
            with self.subTest(text=text), patch.object(Path, "stat") as info, \
                    patch.object(Path, "read_text", return_value=text):
                info.return_value.st_size = len(text)
                with self.assertRaises(Unsupported):
                    launch._outer_options(process, "omp", self.profile + "/omp")

    def test_legacy_codex_relay_is_recreated_not_replayed(self):
        relay = "/private/tmp/herdr-session-relays-501/pane-abcdef/"
        process = {"argv": [BASH, SAFEHOUSE, "--enable=docker", "--env=./.env",
                            "--append-profile=" + relay + "relay.sb", "--",
                            "HERDR_ENV=1", "HERDR_PANE_ID=w1:p1",
                            "HERDR_SOCKET_PATH=" + relay + "report.sock",
                            "AGENT_BROWSER_ARGS=--no-sandbox",
                            str(Path.home() / ".cache/.bun/bin/codex"),
                            "--dangerously-bypass-approvals-and-sandbox"]}
        safe, _ = launch._legacy(process, "codex", "w1:p1")
        self.assertEqual(safe, ["--enable=docker", "--env=./.env"])
        with self.assertRaises(Unsupported):
            launch._legacy(process, "codex", "w1:p2")
        process["argv"] = [arg for arg in process["argv"] if not arg.startswith("HERDR_")]
        with self.assertRaisesRegex(Unsupported, "no matching Codex"):
            launch._legacy(process, "codex", "w1:p1")


if __name__ == "__main__":
    unittest.main()
