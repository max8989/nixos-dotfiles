#!@python@
"""Read TickTick tasks; credentials and cached tasks never enter the Nix store."""
import argparse
from datetime import datetime, time, timedelta, timezone
import json
import os
from pathlib import Path
import stat
import time as clock
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import build_opener, HTTPRedirectHandler, Request
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")


class SyncError(Exception):
    pass


def credentials(path):
    try:
        info = path.stat()
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
            raise SyncError("TickTick credentials must be private (chmod 600).")
        value = json.loads(path.read_text())["accessToken"]
        if not isinstance(value, str) or not value or any(c.isspace() for c in value):
            raise ValueError()
        return value
    except (OSError, ValueError, KeyError, TypeError):
        raise SyncError("Connect TickTick: import your Personal Agent connection.") from None


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Client:
    def __init__(self, token):
        self.token = token
        self.deadline = clock.monotonic() + 45
        self.opener = build_opener(NoRedirect())

    def __call__(self, path):
        remaining = self.deadline - clock.monotonic()
        if remaining <= 0:
            raise SyncError("TickTick sync timed out. Retry when connected.")
        request = Request("https://api.ticktick.com/open/v1" + path,
                          headers={"Authorization": "Bearer " + self.token, "Accept": "application/json"})
        try:
            with self.opener.open(request, timeout=min(10, remaining)) as response:
                body = response.read(8 * 1024 * 1024 + 1)
                if len(body) > 8 * 1024 * 1024:
                    raise SyncError("TickTick returned too much data. Retry later.")
                return json.loads(body)
        except HTTPError as error:
            if error.code in (401, 403):
                raise SyncError("Reconnect TickTick and import the connection again.") from None
            if error.code == 429:
                raise SyncError("TickTick is busy. Retry later.") from None
            raise SyncError("TickTick could not sync. Retry later.") from None
        except (URLError, OSError, ValueError):
            raise SyncError("TickTick is unavailable. Check your connection and retry.") from None


def normalize(task, local_zone):
    if not isinstance(task, dict) or not all(isinstance(task.get(k), str) and task[k].strip()
                                            for k in ("id", "projectId", "title")):
        raise SyncError("TickTick returned an incomplete task. Retry later.")
    due, label = None, ""
    raw = task.get("dueDate") or task.get("startDate")
    if raw:
        try:
            zone = ZoneInfo(task.get("timeZone") or local_zone)
            date = datetime.fromisoformat(raw.replace("Z", "+00:00"))
            if date.tzinfo is None:
                date = date.replace(tzinfo=zone)
            if task.get("isAllDay"):
                day = date.astimezone(zone).date()
                date = datetime.combine(day + timedelta(days=1), time.min, zone) - timedelta(milliseconds=1)
                label = f"{MONTHS[day.month - 1]} {day.day}"
            else:
                display = date.astimezone(ZoneInfo(local_zone))
                label = f"{MONTHS[display.month - 1]} {display.day} {display:%H:%M}"
            due = int(date.timestamp() * 1000)
        except (ValueError, TypeError, AttributeError, ZoneInfoNotFoundError, OverflowError):
            raise SyncError("TickTick returned an invalid task date or timezone.") from None
    return {"id": task["id"], "projectId": task["projectId"],
            "text": " ".join(task["title"].split()), "due": due, "label": label}


def snapshot(request, local_zone):
    projects = request("/project")
    if not isinstance(projects, list) or any(not isinstance(p, dict) or not p.get("id") for p in projects):
        raise SyncError("TickTick returned an incomplete project list.")
    # The virtual Inbox may be omitted by older API versions; it still needs
    # an explicit read so an empty project list cannot silently hide its tasks.
    projects = [p for p in projects if not p.get("closed") and p.get("kind") != "NOTE"]
    if not any(p["id"] == "inbox" for p in projects):
        projects.append({"id": "inbox", "name": "Inbox"})
    tasks = {}
    for project in projects:
        data = request("/project/" + quote(project["id"], safe="") + "/data")
        if not isinstance(data, dict) or not isinstance(data.get("tasks"), list):
            raise SyncError("TickTick returned an incomplete task list.")
        for task in data["tasks"]:
            if not isinstance(task, dict):
                raise SyncError("TickTick returned an incomplete task.")
            if task.get("status", 0) != 0 or task.get("kind") == "NOTE":
                continue
            item = normalize(task, local_zone)
            item["project"] = project.get("name") or data.get("project", {}).get("name") or "Inbox"
            tasks[(item["projectId"], item["id"])] = item
    return {"ok": True, "tasks": sorted(tasks.values(), key=lambda t: (t["due"] is None, t["due"] or 0, t["text"])),
            "syncedAt": datetime.now(timezone.utc).isoformat()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials", type=Path, default=Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "quickshell/ticktick.json")
    args = parser.parse_args()
    try:
        result = snapshot(Client(credentials(args.credentials)), os.environ.get("TZ", "UTC"))
    except SyncError as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
