#!/usr/bin/env python3
"""Post 'recheck' on open master changes in openstack/cinder and openstack/manila whose current
patch set has Zuul Verified -1, for every account in accounts.json marked "recheck": true.

Skipped: WIP changes; changes Zuul cannot merge (merge conflict or a failed Depends-On), which a
recheck can never clear; and changes where a recheck newer than Zuul's last message is still
recent enough to be in flight. Posts over SSH as sdodsley (key lives in WSL). --dry-run only lists.
"""
import datetime as dt
import subprocess
import sys

from gerrit_dashboard import get, load_accounts, parse

PROJECTS = ["openstack/cinder", "openstack/manila"]  # exact names: specs and tempest plugins are excluded
SSH = ["wsl", "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=20", "-p", "29418", "sdodsley@review.opendev.org"]
IN_FLIGHT_HOURS = 20  # a recheck older than this that Zuul never answered counts as lost, not in flight
UNRECHECKABLE = ("merge failed", "failed to merge")  # Zuul -1 reasons that a recheck cannot clear


def main():
    dry = "--dry-run" in sys.argv
    now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
    ids = [a["id"] for a in load_accounts() if a.get("recheck") and a.get("id")]
    if not ids:
        print("no accounts with recheck enabled")
        return
    query = "status:open branch:master (%s) (%s)" % (
        " OR ".join("owner:%d" % i for i in ids),
        " OR ".join("project:" + p for p in PROJECTS),
    )
    changes = get("/changes/", {"q": query, "o": ["DETAILED_LABELS", "CURRENT_REVISION", "DETAILED_ACCOUNTS", "MESSAGES"], "n": 200})
    todo = []
    for c in changes:
        n = c["_number"]
        if c.get("work_in_progress"):
            print("skip WIP", n)
            continue
        ver = c.get("labels", {}).get("Verified", {}).get("all", [])
        if not any(v.get("name") == "Zuul" and v.get("value", 0) < 0 for v in ver):
            continue
        if c.get("mergeable") is False:
            print("skip merge conflict", n)
            continue
        msgs = c.get("messages", [])
        zuul_msgs = [m for m in msgs if m["author"].get("name") == "Zuul"]
        last_zuul = zuul_msgs[-1]["date"] if zuul_msgs else ""
        if zuul_msgs and any(k in zuul_msgs[-1].get("message", "").lower() for k in UNRECHECKABLE):
            print("skip unmergeable (conflict or failed Depends-On)", n)
            continue
        last_re = max((m["date"] for m in msgs if m.get("message", "").strip().lower().endswith("recheck")), default="")
        if last_re and last_re > last_zuul and now - parse(last_re) < dt.timedelta(hours=IN_FLIGHT_HOURS):
            print("skip in flight", n)
            continue
        todo.append((n, c["current_revision_number"], c["owner"].get("name", "?"), c["subject"]))
    for n, ps, owner, subj in todo:
        if dry:
            print("DRY-RUN would recheck %d,%d [%s] %s" % (n, ps, owner, subj))
            continue
        try:
            r = subprocess.run(SSH + ["gerrit", "review", "-m", "recheck", "%d,%d" % (n, ps)], capture_output=True, text=True, timeout=120)
            status = "ok" if r.returncode == 0 else "FAILED " + r.stderr.strip()
        except (subprocess.TimeoutExpired, OSError) as e:
            status = "FAILED %s (the comment may still have been posted)" % e.__class__.__name__
        print("recheck %d,%d [%s] %s -> %s" % (n, ps, owner, subj, status))
    print("%d change(s) %s" % (len(todo), "listed" if dry else "processed"))


if __name__ == "__main__":
    main()
