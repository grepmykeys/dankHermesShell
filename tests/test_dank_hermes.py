#!/usr/bin/env python3
"""Tests for the dank-hermes helper.

Run: python3 -m unittest tests/test_dank_hermes.py
"""

from __future__ import annotations

import importlib.util
import json
import os
import sqlite3
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
HELPER = ROOT / "bin" / "dank-hermes"


def load_helper():
    spec = importlib.util.spec_from_loader(
        "dank_hermes", importlib.machinery.SourceFileLoader("dank_hermes", str(HELPER))
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


h = load_helper()

SESSIONS_SCHEMA = """
CREATE TABLE sessions (
    id TEXT PRIMARY KEY, source TEXT NOT NULL, display_name TEXT, title TEXT,
    model TEXT, started_at REAL NOT NULL, last_activity_at REAL,
    last_activity_description TEXT, message_count INTEGER DEFAULT 0,
    tool_call_count INTEGER DEFAULT 0, input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0, estimated_cost_usd REAL DEFAULT 0,
    cwd TEXT, git_branch TEXT, archived INTEGER NOT NULL DEFAULT 0,
    pinned INTEGER NOT NULL DEFAULT 0, hidden INTEGER NOT NULL DEFAULT 0,
    profile_name TEXT
);
CREATE TABLE session_model_usage (
    session_id TEXT NOT NULL, model TEXT NOT NULL,
    billing_provider TEXT NOT NULL DEFAULT '', billing_base_url TEXT NOT NULL DEFAULT '',
    billing_mode TEXT NOT NULL DEFAULT '', task TEXT NOT NULL DEFAULT '',
    api_call_count INTEGER NOT NULL DEFAULT 0, input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0, cache_read_tokens INTEGER NOT NULL DEFAULT 0,
    cache_write_tokens INTEGER NOT NULL DEFAULT 0, reasoning_tokens INTEGER NOT NULL DEFAULT 0,
    estimated_cost_usd REAL NOT NULL DEFAULT 0, actual_cost_usd REAL NOT NULL DEFAULT 0,
    cost_status TEXT, cost_source TEXT, first_seen REAL, last_seen REAL,
    PRIMARY KEY (session_id, model, billing_provider, billing_base_url, billing_mode, task)
);
"""


class TempHermes(unittest.TestCase):
    """Builds a throwaway HERMES_HOME with a synthetic state.db."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        os.makedirs(self.home / "runtime", exist_ok=True)
        db = self.home / "state.db"
        conn = sqlite3.connect(db)
        conn.executescript(SESSIONS_SCHEMA)
        now = time.time()
        conn.execute(
            "INSERT INTO sessions (id, source, title, model, started_at, last_activity_at,"
            " message_count, tool_call_count, input_tokens, output_tokens, estimated_cost_usd,"
            " cwd, git_branch, archived, hidden)"
            " VALUES ('s_active','desktop','Wire up the widget','test/model-a',?,?,12,4,1000,500,0.25,"
            " '/home/p/proj','main',0,0)",
            (now - 600, now - 5),
        )
        conn.execute(
            "INSERT INTO sessions (id, source, display_name, model, started_at, last_activity_at,"
            " archived, hidden) VALUES ('s_old','telegram','Old chat','test/model-b',?,?,0,0)",
            (now - 8 * 86400, now - 8 * 86400),
        )
        conn.execute(
            "INSERT INTO sessions (id, source, title, model, started_at, last_activity_at,"
            " archived, hidden) VALUES ('s_gone','desktop','Archived one','test/model-a',?,?,1,0)",
            (now - 9 * 86400, now - 9 * 86400),
        )
        conn.execute(
            "INSERT INTO session_model_usage (session_id, model, api_call_count, input_tokens,"
            " output_tokens, cache_read_tokens, reasoning_tokens, estimated_cost_usd, first_seen, last_seen)"
            " VALUES ('s_active','test/model-a',3,1000,500,8000,100,0.25,?,?)",
            (now - 590, now - 30),
        )
        conn.execute(
            "INSERT INTO session_model_usage (session_id, model, api_call_count, input_tokens,"
            " output_tokens, estimated_cost_usd, first_seen, last_seen)"
            " VALUES ('s_old','test/model-b',9,5000,900,1.5,?,?)",
            (now - 8 * 86400, now - 8 * 86400 + 60),
        )
        conn.commit()
        conn.close()

        (self.home / "gateway_state.json").write_text(json.dumps({
            "pid": os.getpid(), "gateway_state": "running", "code_version": "0.0.0-test",
            "active_agents": 0, "platforms": {"telegram": {"state": "connected"},
                                              "discord": {"state": "error"}},
        }), encoding="utf-8")
        (self.home / "runtime" / "active_sessions.json").write_text(json.dumps({
            "entries": [{"session_id": "s_active", "surface": "desktop", "pid": os.getpid(),
                         "started_at": now - 600}],
        }), encoding="utf-8")
        (self.home / "config.yaml").write_text(
            "model:\n  default: test/model-a\n  provider: nous\n  base_url: http://x/v1\n"
            "agent:\n  max_turns: 150\n  reasoning_effort: medium\n",
            encoding="utf-8",
        )

        self._old_env = os.environ.get("HERMES_HOME")
        os.environ["HERMES_HOME"] = str(self.home)

    def tearDown(self):
        if self._old_env is None:
            os.environ.pop("HERMES_HOME", None)
        else:
            os.environ["HERMES_HOME"] = self._old_env
        self.tmp.cleanup()


class TestFormatting(unittest.TestCase):
    def test_tokens(self):
        self.assertEqual(h.fmt_tokens(0), "0")
        self.assertEqual(h.fmt_tokens(999), "999")
        self.assertEqual(h.fmt_tokens(1500), "1.5k")
        self.assertEqual(h.fmt_tokens(80677), "81k")
        self.assertEqual(h.fmt_tokens(2_500_000), "2.5M")

    def test_cost(self):
        self.assertEqual(h.fmt_cost(0), "$0.00")
        self.assertEqual(h.fmt_cost(0.0032), "$0.0032")
        self.assertEqual(h.fmt_cost(1.5), "$1.50")

    def test_ago(self):
        now = time.time()
        self.assertEqual(h.fmt_ago(now), "just now")
        self.assertEqual(h.fmt_ago(now - 300), "5m ago")
        self.assertEqual(h.fmt_ago(now - 7200), "2h ago")
        self.assertEqual(h.fmt_ago(now - 3 * 86400), "3d ago")
        self.assertEqual(h.fmt_ago(None), "never")


class TestConfigParsing(unittest.TestCase):
    def test_nested_and_scalar(self):
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as fh:
            fh.write(
                "# comment\n"
                "model:\n"
                "  default: 'a/b'\n"
                "  provider: nous\n"
                "  base_url: https://example/v1\n"
                "database:\n"
                "  journal_mode: wal\n"
                "agent:\n"
                "  reasoning_effort: medium\n"
                "  personalities: {}\n"
                "top_scalar: hello\n"
            )
            path = fh.name
        try:
            cfg = h.parse_config(path)
        finally:
            os.unlink(path)
        self.assertEqual(cfg["model.default"], "a/b")
        self.assertEqual(cfg["model.provider"], "nous")
        self.assertEqual(cfg["agent.reasoning_effort"], "medium")
        self.assertEqual(cfg["top_scalar"], "hello")
        # nested keys are namespaced so a scalar and a block key never collide
        self.assertEqual(cfg["model.base_url"], "https://example/v1")

    def test_missing_file(self):
        self.assertEqual(h.parse_config("/nonexistent/config.yaml"), {})


class TestWindows(unittest.TestCase):
    def test_today_is_local_midnight(self):
        import datetime as dt
        start = h.day_start()
        moment = dt.datetime.fromtimestamp(start)
        self.assertEqual((moment.hour, moment.minute, moment.second), (0, 0, 0))

    def test_week_is_seven_day_span(self):
        w = h.window_starts()
        self.assertAlmostEqual(w["today"] - w["week"], 6 * 86400, delta=1)


class TestStatus(TempHermes):
    def test_status_reports_gateway_agent_and_live_sessions(self):
        res = h.cmd_status(type("A", (), {})())
        self.assertTrue(res["ok"])
        self.assertTrue(res["gateway"]["running"])
        self.assertEqual(res["gateway"]["connectedPlatforms"], ["telegram"])
        self.assertEqual(res["agent"]["configuredModel"], "test/model-a")
        self.assertEqual(res["agent"]["provider"], "nous")
        self.assertTrue(res["agent"]["active"])
        self.assertEqual(len(res["liveSessions"]), 1)
        self.assertTrue(res["liveSessions"][0]["alive"])

    def test_dead_gateway_pid_is_not_running(self):
        (self.home / "gateway_state.json").write_text(json.dumps({"pid": 999999}), encoding="utf-8")
        res = h.cmd_status(type("A", (), {})())
        self.assertFalse(res["gateway"]["running"])


class TestUsage(TempHermes):
    def test_empty_week_does_not_show_all_time_as_weekly_usage(self):
        with sqlite3.connect(self.home / "state.db") as conn:
            conn.execute("UPDATE session_model_usage SET last_seen = ?", (time.time() - 40 * 86400,))
        res = h.cmd_usage(type("A", (), {"days": 7})())
        self.assertEqual(res["week"]["inputTokens"], 0)
        self.assertEqual(res["byModel"], [])

    def test_today_excludes_old_rows(self):
        res = h.cmd_usage(type("A", (), {"days": 7})())
        self.assertTrue(res["ok"])
        self.assertEqual(res["today"]["inputTokens"], 1000)
        self.assertEqual(res["today"]["outputTokens"], 500)
        self.assertEqual(res["today"]["calls"], 3)
        self.assertAlmostEqual(res["today"]["cost"], 0.25)

    def test_all_time_aggregates_everything(self):
        res = h.cmd_usage(type("A", (), {"days": 7})())
        self.assertEqual(res["allTime"]["inputTokens"], 6000)
        self.assertEqual(res["allTime"]["outputTokens"], 1400)
        self.assertAlmostEqual(res["allTime"]["cost"], 1.75)

    def test_series_has_one_entry_per_day_and_sums(self):
        res = h.cmd_usage(type("A", (), {"days": 7})())
        self.assertEqual(len(res["series"]), 7)
        self.assertEqual(sum(d["tokens"] for d in res["series"]), 1000 + 500)

    def test_by_model_sorted_by_week_volume(self):
        res = h.cmd_usage(type("A", (), {"days": 7})())
        self.assertTrue(res["byModel"])
        self.assertEqual(res["byModel"][0]["model"], "test/model-a")

    def test_missing_db_is_an_error_not_a_crash(self):
        os.unlink(self.home / "state.db")
        res = h.cmd_usage(type("A", (), {"days": 7})())
        self.assertFalse(res["ok"])
        self.assertIn("state.db", res["error"])


class TestSessions(TempHermes):
    def test_lists_newest_first_and_skips_archived(self):
        res = h.cmd_sessions(type("A", (), {"limit": 20, "include_hidden": False})())
        ids = [s["id"] for s in res["sessions"]]
        self.assertEqual(ids, ["s_active", "s_old"])
        self.assertNotIn("s_gone", ids)

    def test_label_prefers_title_then_display_name(self):
        res = h.cmd_sessions(type("A", (), {"limit": 20, "include_hidden": False})())
        labels = {s["id"]: s["label"] for s in res["sessions"]}
        self.assertEqual(labels["s_active"], "Wire up the widget")
        self.assertEqual(labels["s_old"], "Old chat")

    def test_active_flag_tracks_live_sessions(self):
        res = h.cmd_sessions(type("A", (), {"limit": 20, "include_hidden": False})())
        flags = {s["id"]: s["active"] for s in res["sessions"]}
        self.assertTrue(flags["s_active"])
        self.assertFalse(flags["s_old"])

    def test_limit_is_respected_and_clamped(self):
        res = h.cmd_sessions(type("A", (), {"limit": 1, "include_hidden": False})())
        self.assertEqual(len(res["sessions"]), 1)

    def test_tokens_and_cost_are_pretty(self):
        res = h.cmd_sessions(type("A", (), {"limit": 20, "include_hidden": False})())
        first = res["sessions"][0]
        self.assertEqual(first["tokens"], 1500)
        self.assertEqual(first["tokensPretty"], "1.5k")
        self.assertEqual(first["costPretty"], "$0.25")


class TestReadOnly(TempHermes):
    def test_read_only_connection_closes_after_use(self):
        with h.connect_ro(str(self.home / "state.db")) as conn:
            self.assertEqual(conn.execute("SELECT 1").fetchone()[0], 1)
        with self.assertRaises(sqlite3.ProgrammingError):
            conn.execute("SELECT 1")

    def test_helper_never_writes_to_hermes_state(self):
        before = (self.home / "state.db").read_bytes()
        mtimes = {p: p.stat().st_mtime for p in self.home.rglob("*") if p.is_file()}
        h.cmd_status(type("A", (), {})())
        h.cmd_usage(type("A", (), {"days": 7})())
        h.cmd_sessions(type("A", (), {"limit": 5, "include_hidden": False})())
        self.assertEqual((self.home / "state.db").read_bytes(), before)
        self.assertEqual(mtimes, {p: p.stat().st_mtime for p in self.home.rglob("*") if p.is_file()})

    def test_no_new_files_appear_in_hermes_home(self):
        known = {p.name for p in self.home.iterdir()}
        h.cmd_sessions(type("A", (), {"limit": 5, "include_hidden": False})())
        self.assertEqual(known, {p.name for p in self.home.iterdir()})


class TestActions(unittest.TestCase):
    def test_background_answer_is_private_and_rejects_overlap(self):
        import subprocess
        children = []
        real_popen = subprocess.Popen

        def spawn(*args, **kwargs):
            child = real_popen(*args, **kwargs)
            children.append(child)
            return child

        with tempfile.TemporaryDirectory() as state_home:
            with patch.dict(os.environ, {"XDG_STATE_HOME": state_home}), patch.object(
                h, "hermes_argv", return_value=[sys.executable, "-c", "import time; time.sleep(60)"]
            ), patch.object(h.subprocess, "Popen", side_effect=spawn):
                try:
                    first = h.cmd_prompt(type("A", (), {"text": "first"})())
                    self.assertTrue(first["ok"])
                    second = h.cmd_prompt(type("A", (), {"text": "second"})())
                    self.assertFalse(second["ok"])
                    self.assertIn("already running", second["error"])
                    self.assertEqual(Path(first["logPath"]).stat().st_mode & 0o777, 0o600)
                finally:
                    for child in children:
                        child.terminate()
                        child.wait(timeout=5)

    def test_query_files_are_unique_and_private(self):
        with tempfile.TemporaryDirectory() as state_home:
            with patch.dict(os.environ, {"XDG_STATE_HOME": state_home}):
                first = Path(h.write_query_file("first prompt"))
                second = Path(h.write_query_file("second prompt"))
                self.assertNotEqual(first, second)
                self.assertEqual(first.read_text(), "first prompt")
                self.assertEqual(second.read_text(), "second prompt")
                self.assertEqual(first.stat().st_mode & 0o777, 0o600)
                self.assertEqual(first.parent.stat().st_mode & 0o777, 0o700)

    def test_terminal_argv_has_no_shell_strings(self):
        res = h.cmd_terminal_argv(type("A", (), {"query": "", "resume": "", "terminal": ""})())
        if not res["ok"]:
            self.skipTest("no terminal emulator available")
        self.assertIsInstance(res["argv"], list)
        self.assertIn("chat", res["argv"])
        self.assertNotIn("sh", res["argv"][0])

    def test_query_is_passed_by_file_never_inline(self):
        argv_obj = type("A", (), {"query": "rm -rf / ; echo $(whoami)", "resume": "", "terminal": "cat"})()
        res = h.cmd_terminal_argv(argv_obj)
        if not res["ok"]:
            self.skipTest("cat not usable as terminal")
        self.assertIn("--query-file", res["argv"])
        path = res["argv"][res["argv"].index("--query-file") + 1]
        self.assertTrue(os.path.isabs(path))
        with open(path, encoding="utf-8") as fh:
            self.assertEqual(fh.read(), "rm -rf / ; echo $(whoami)")
        self.assertNotIn("rm -rf / ; echo $(whoami)", " ".join(res["argv"]))
        os.unlink(path)

    def test_resume_is_forwarded(self):
        res = h.cmd_terminal_argv(type("A", (), {"query": "", "resume": "sess-1", "terminal": "cat"})())
        if not res["ok"]:
            self.skipTest("cat not usable as terminal")
        self.assertEqual(res["argv"][-2:], ["--resume", "sess-1"])

    def test_doctor_reports_each_check(self):
        res = h.cmd_doctor(type("A", (), {})())
        names = {c["name"] for c in res["checks"]}
        self.assertIn("hermes executable", names)
        self.assertIn("state.db readable", names)
        for check in res["checks"]:
            self.assertIn("ok", check)


class TestAnswer(unittest.TestCase):
    def test_running_query_is_reported_until_hermes_exits(self):
        with tempfile.TemporaryDirectory() as state_home:
            answer_dir = Path(state_home) / "dank-hermes"
            answer_dir.mkdir()
            (answer_dir / "last-answer.log").write_text("partial answer", encoding="utf-8")
            with patch.dict(os.environ, {"XDG_STATE_HOME": state_home}):
                with patch.object(h, "_process_table", return_value=[
                    ("12345", "/home/p/.hermes/venv/bin/hermes chat --oneshot --source dankhermes")
                ]):
                    self.assertTrue(h.cmd_answer(None)["running"])
                with patch.object(h, "_process_table", return_value=[]):
                    self.assertFalse(h.cmd_answer(None)["running"])


class TestCliSurface(unittest.TestCase):
    def test_main_returns_error_json_on_failure(self):
        import io
        import contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = h.main(["usage"])  # no HERMES_HOME override -> real home
        payload = json.loads(buf.getvalue())
        self.assertIn("ok", payload)
        self.assertIsInstance(code, int)


if __name__ == "__main__":
    unittest.main(verbosity=2)
