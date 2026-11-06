"""TickTick coverage, date semantics and failure handling without live writes."""
import importlib.util
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime
from zoneinfo import ZoneInfo

spec = importlib.util.spec_from_file_location("ticktick", sys.argv.pop(1))
importer_path = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(spec.origin).with_name("quickshell-ticktick-import.mjs")
sys.dont_write_bytecode = True
ticktick = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ticktick)


class TickTickTests(unittest.TestCase):
    def task(self, **changes):
        return dict(id="task1", projectId="work", title="Review 中文", status=0, **changes)

    def test_all_day_task_expires_at_end_of_its_day_across_dst(self):
        task = ticktick.normalize(self.task(dueDate="2026-11-01T04:00:00+0000",
                                           isAllDay=True, timeZone="America/Toronto"), "UTC")
        expected = datetime(2026, 11, 1, 23, 59, 59, 999000, tzinfo=ZoneInfo("America/Toronto"))
        self.assertEqual(task["due"], int(expected.timestamp() * 1000))
        self.assertEqual(task["label"], "Nov 1")

    def test_timed_task_and_start_only_task_keep_the_exact_instant(self):
        for field in ("dueDate", "startDate"):
            task = ticktick.normalize(self.task(**{field: "2026-11-05T15:30:00+0000"}), "America/Toronto")
            self.assertEqual(task["due"], 1793892600000)
            self.assertEqual(task["label"], "Nov 5 10:30")

    def test_undated_tasks_and_plain_text_titles_are_preserved(self):
        task = ticktick.normalize(self.task(), "America/Toronto")
        self.assertIsNone(task["due"])
        self.assertEqual(task["text"], "Review 中文")
        self.assertEqual(task["id"], "task1")
        self.assertEqual(task["projectId"], "work")

    def test_all_projects_inbox_undated_and_overdue_are_covered_and_deduplicated(self):
        project_tasks = [self.task(), self.task(dueDate="2020-01-01T00:00:00+0000")]
        def request(path):
            if path == "/project":
                return [{"id": "work"}, {"id": "inbox"}, {"id": "archive", "closed": True},
                        {"id": "notes", "kind": "NOTE"}]
            if path == "/project/work/data":
                return {"project": {"name": "Work"}, "tasks": project_tasks + [
                    dict(self.task(), id="done", status=2), dict(self.task(), id="abandoned", status=-1)]}
            if path == "/project/inbox/data":
                return {"project": {"name": "Inbox"}, "tasks": [dict(self.task(), id="inbox1", projectId="inbox")]}
            self.fail("Unexpected request " + path)
        result = ticktick.snapshot(request, "America/Toronto")
        self.assertTrue(result["ok"])
        self.assertEqual({t["id"] for t in result["tasks"]}, {"task1", "inbox1"})
        self.assertEqual(next(t for t in result["tasks"] if t["id"] == "inbox1")["project"], "Inbox")

    def test_missing_inbox_in_project_response_is_fetched_explicitly(self):
        seen = []
        def request(path):
            seen.append(path)
            return [] if path == "/project" else {"tasks": []}
        self.assertEqual(ticktick.snapshot(request, "UTC")["tasks"], [])
        self.assertIn("/project/inbox/data", seen)

    def test_partial_or_malformed_results_fail_instead_of_becoming_zero_tasks(self):
        for broken in ({}, {"tasks": None}, {"tasks": [{}]}):
            with self.subTest(broken=broken), self.assertRaises(ticktick.SyncError):
                ticktick.snapshot(lambda path: [{"id": "work"}] if path == "/project" else broken, "UTC")

    def test_bad_dates_are_reported(self):
        with self.assertRaises(ticktick.SyncError):
            ticktick.normalize(self.task(dueDate="not a date"), "UTC")

    def test_credentials_are_private_and_never_part_of_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ticktick.json"
            path.write_text(json.dumps({"accessToken": "secret-value"}))
            path.chmod(0o644)
            with self.assertRaisesRegex(ticktick.SyncError, "private"):
                ticktick.credentials(path)
            path.chmod(0o600)
            self.assertEqual(ticktick.credentials(path), "secret-value")

    def test_import_copies_only_the_configured_owners_token_with_private_permissions(self):
        source = importer_path.read_text()
        source = source.replace("@python@", sys.executable)
        sealed = json.loads(subprocess.run(["node", "--input-type=module", "-e", '''
import {createCipheriv} from 'node:crypto';
const key=Buffer.alloc(32,1), nonce=Buffer.alloc(12,2);
const cipher=createCipheriv('aes-256-gcm',key,nonce);
const encrypted=Buffer.concat([cipher.update('fixture-token'),cipher.final()]);
console.log(JSON.stringify({key:key.toString('base64'), token:Buffer.concat([nonce,cipher.getAuthTag(),encrypted]).toString('base64')}));
'''], capture_output=True, text=True, check=True).stdout)
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            db_path = base / "pocketbase/pb_data/data.db"
            db_path.parent.mkdir(parents=True)
            with sqlite3.connect(db_path) as db:
                db.execute("create table users (id text, email text)")
                db.execute("create table integrations (owner text, key text, data text)")
                db.executemany("insert into users values (?,?)", [("own", "own@example.test"), ("other", "other@example.test")])
                db.executemany("insert into integrations values (?, 'ticktick', ?)", [
                    ("own", json.dumps({"token": sealed["token"]})),
                    ("other", json.dumps({"token": "do-not-import"}))])
            (base / ".env").write_text("OWNER_EMAIL='own@example.test'\nTOKEN_ENCRYPTION_KEY='" + sealed["key"] + "'\n")
            importer = base / "import.mjs"
            importer.write_text(source)
            env = {**os.environ, "XDG_CONFIG_HOME": str(base / "config")}
            result = subprocess.run(["node", str(importer), str(base)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            saved = base / "config/quickshell/ticktick.json"
            self.assertEqual(json.loads(saved.read_text()), {"accessToken": "fixture-token"})
            self.assertEqual(saved.stat().st_mode & 0o777, 0o600)
            self.assertNotIn("fixture-token", result.stdout + result.stderr)
            (base / ".env").write_text("OWNER_EMAIL='absent@example.test'\n")
            failed = subprocess.run(["node", str(importer), str(base)], env=env, capture_output=True, text=True)
            self.assertEqual(failed.returncode, 1)
            self.assertEqual(json.loads(saved.read_text()), {"accessToken": "fixture-token"})


unittest.main()
