"""Consumer-visible restart safety regressions; no live agents are touched."""

import json
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tempfile
import unittest

from adapters import Unsupported, agent_process, codex_writer_owns_session, restart_options, resume_arguments


SESSION_ID = "01234567-89ab-4cde-8fab-0123456789ab"


class OptionsTests(unittest.TestCase):
    def test_resume_drops_old_prompt_but_keeps_configuration(self):
        self.assertEqual(
            restart_options("codex", ["--dangerously-bypass-approvals-and-sandbox", "--no-daemon", "-m", "gpt-5", "-c", "model_reasoning_effort=high", "resume", SESSION_ID, "repeat this destructive prompt", "-p", "work", "--image", "secret.png"], "/work"),
            ["-m", "gpt-5", "-c", "model_reasoning_effort=high", "-p", "work"],
        )

    def test_omp_profile_and_resources_survive(self):
        self.assertEqual(restart_options("omp", ["--profile", "work", "--config", "./agent.yml", "--add-dir", "../other", "--session", "/old", "@prompt", "do not replay"], "/work"), ["--profile", "work", "--config", "./agent.yml", "--add-dir", "../other"])

    def test_unsafe_shapes_fail_closed(self):
        cases = [("codex", ["exec", "hi"]), ("codex", ["--remote", "ws://host"]), ("codex", ["fork", SESSION_ID]), ("omp", ["--mode", "rpc"]), ("omp", ["--unknown-extension", "x"]), ("claude", ["--fork-session"]), ("claude", ["--print", "hi"]), ("opencode", ["attach", "http://localhost"]), ("omp", ["--api-key", "secret"])]
        for kind, argv in cases:
            with self.subTest(kind=kind, argv=argv), self.assertRaises(Unsupported):
                restart_options(kind, argv, "/work")

    def test_credentials_are_not_copied_into_restart_recipes(self):
        for kind, argv in [("codex", ["-c", "mcp_servers.private.env.TOKEN=secret"]), ("claude", ["--settings", '{"env":{"TOKEN":"secret"}}']), ("claude", ["--mcp-config", '{"server":{"token":"secret"}}'])]:
            with self.subTest(kind=kind), self.assertRaises(Unsupported):
                restart_options(kind, argv, "/work")

    def test_claude_variadic_configuration_is_not_silently_truncated(self):
        self.assertEqual(restart_options("claude", ["--add-dir=/one", "--add-dir=/two", "--settings", "/settings.json"], "/work"), ["--add-dir=/one", "--add-dir=/two", "--settings", "/settings.json"])
        with self.assertRaises(Unsupported):
            restart_options("claude", ["--add-dir", "/one", "/two"], "/work")

    def test_dash_separator_does_not_turn_prompt_into_options(self):
        self.assertEqual(restart_options("omp", ["--model", "model", "--", "--config", "secret"], "/work"), ["--model", "model"])

    def test_cwd_override_must_match_saved_project(self):
        with self.assertRaises(Unsupported):
            restart_options("codex", ["-C", "/different"], "/work")


class ProcessTests(unittest.TestCase):
    @staticmethod
    def process(pid, *argv):
        return {"pid": pid, "argv": list(argv), "cwd": "/work"}

    def test_codex_native_child_selected_over_node_launcher(self):
        node = self.process(10, "/bin/node", "/global/node_modules/@openai/codex/bin/codex.js", "--model", "model")
        native = self.process(11, "/vendor/aarch64-apple-darwin/bin/codex", "--model", "model")
        result = agent_process("codex", {"foreground_processes": [node, native]})
        self.assertEqual(result["pid"], 11)
        self.assertEqual(result["agent_args"], ["--model", "model"])

    def test_two_native_writers_are_ambiguous(self):
        with self.assertRaises(Unsupported):
            agent_process("codex", {"foreground_processes": [self.process(10, "/bin/codex"), self.process(11, "/other/codex")]})

    def test_mismatched_node_and_native_options_are_not_assumed_parent_child(self):
        with self.assertRaises(Unsupported):
            agent_process("codex", {"foreground_processes": [self.process(10, "/bin/node", "/node_modules/@openai/codex/bin/codex.js", "--model", "one"), self.process(11, "/bin/codex", "--model", "two")]})

    def test_shell_wrappers_and_brokers_are_not_interactive_agents(self):
        for argv in [("/bin/bash", "/bin/omp"), ("/bin/codex", "app-server"), ("/bin/bun", "/tmp/unrelated/cli.js")]:
            with self.subTest(argv=argv), self.assertRaises(Unsupported):
                agent_process("codex", {"foreground_processes": [self.process(10, *argv)]})


class ResumeTests(unittest.TestCase):
    def test_file_resume_requires_real_header_and_matching_project(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "session.jsonl"
            ref = {"agent": "omp", "kind": "path", "value": str(path)}
            with self.assertRaises(Unsupported):
                resume_arguments("omp", ref, directory)
            for header in [{"type": "message", "id": SESSION_ID, "cwd": directory}, {"type": "session", "id": SESSION_ID, "cwd": "/another"}, {"type": "session", "cwd": directory}]:
                path.write_text(json.dumps(header) + "\n")
                with self.subTest(header=header), self.assertRaises(Unsupported):
                    resume_arguments("omp", ref, directory)
            path.write_text(json.dumps({"type": "session", "id": SESSION_ID, "cwd": directory}) + "\n")
            self.assertEqual(resume_arguments("omp", ref, directory), ["--session", str(path)])

    def test_omp_title_slot_is_not_the_session_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "session.jsonl"
            title = {"type": "title", "v": 1, "title": "Saved conversation", "pad": " "}
            header = {"type": "session", "version": 3, "id": SESSION_ID, "cwd": directory}
            path.write_text(json.dumps(title) + "\n" + json.dumps(header) + "\n")
            ref = {"agent": "omp", "kind": "path", "value": str(path)}
            self.assertEqual(resume_arguments("omp", ref, directory), ["--session", str(path)])
            for prefix in ({"type": "message"}, title):
                path.write_text(json.dumps(prefix) + "\n" + json.dumps(title) + "\n" + json.dumps(header) + "\n")
                with self.subTest(prefix=prefix), self.assertRaises(Unsupported):
                    resume_arguments("omp", ref, directory)

    def test_uuid_is_exact_and_codex_forces_original_cwd(self):
        self.assertEqual(resume_arguments("codex", {"kind": "id", "value": SESSION_ID}, "/work"), ["resume", SESSION_ID, "-C", "/work"])
        self.assertEqual(resume_arguments("claude", {"kind": "id", "value": SESSION_ID}, "/work"), ["--resume", SESSION_ID])
        for value in ["latest", SESSION_ID[:8], "--last", SESSION_ID.replace("-", "")]:
            with self.subTest(value=value), self.assertRaises(Unsupported):
                resume_arguments("codex", {"kind": "id", "value": value}, "/work")

    def test_reference_cannot_cross_agent_kind(self):
        with self.assertRaises(Unsupported):
            resume_arguments("claude", {"agent": "codex", "kind": "id", "value": SESSION_ID}, "/work")

    def test_opencode_ids_cannot_be_paths_or_selectors(self):
        self.assertEqual(resume_arguments("opencode", {"kind": "id", "value": "ses_abc123XYZ"}, "/work"), ["--session", "ses_abc123XYZ"])
        for value in ["latest", "ses_../../file", "ses_"]:
            with self.subTest(value=value), self.assertRaises(Unsupported):
                resume_arguments("opencode", {"kind": "id", "value": value}, "/work")


@unittest.skipUnless(shutil.which("lsof"), "native writer inspection requires lsof")
class CodexWriterOwnershipTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        self.locks = self.root / "thread-writer-locks"
        self.locks.mkdir()
        self.path = self.locks / f"{SESSION_ID}.lock"
        self.lsof = shutil.which("lsof")

    def opener(self, mode, path=None):
        script = (
            "import fcntl, sys\n"
            "with open(sys.argv[1], 'a+b') as file:\n"
            "    if sys.argv[2] == 'lock':\n"
            "        fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)\n"
            "    elif sys.argv[2] == 'shared':\n"
            "        fcntl.flock(file, fcntl.LOCK_SH | fcntl.LOCK_NB)\n"
            "    print('ready', flush=True)\n"
            "    sys.stdin.read(1)\n"
        )
        child = subprocess.Popen(
            [sys.executable, "-I", "-B", "-c", script, str(path or self.path), mode],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
        )

        def cleanup():
            child.stdin.close()
            child.wait(timeout=5)
            child.stdout.close()

        self.addCleanup(cleanup)
        self.assertTrue(select.select([child.stdout], [], [], 5)[0], "lock helper did not start")
        self.assertEqual(child.stdout.readline(), "ready\n")
        return child

    def test_exact_session_owned_by_native_process_is_verified(self):
        child = self.opener("lock")
        self.assertTrue(codex_writer_owns_session(child.pid, SESSION_ID, self.lsof))
        self.assertFalse(codex_writer_owns_session(child.pid, "11234567-89ab-4cde-8fab-0123456789ab", self.lsof))

    def test_open_but_unlocked_file_is_not_session_ownership(self):
        child = self.opener("open")
        self.assertFalse(codex_writer_owns_session(child.pid, SESSION_ID, self.lsof))

    def test_shared_reader_lock_is_not_native_writer_ownership(self):
        child = self.opener("shared")
        self.assertFalse(codex_writer_owns_session(child.pid, SESSION_ID, self.lsof))

    def test_another_process_holding_the_lock_is_not_accepted(self):
        self.opener("lock")
        pretender = self.opener("open")
        self.assertFalse(codex_writer_owns_session(pretender.pid, SESSION_ID, self.lsof))

    def test_matching_filename_outside_writer_directory_is_not_accepted(self):
        child = self.opener("lock", self.root / f"{SESSION_ID}.lock")
        self.assertFalse(codex_writer_owns_session(child.pid, SESSION_ID, self.lsof))


if __name__ == "__main__":
    unittest.main()
