#!/usr/bin/env python3
"""Post 'recheck' on open master changes in openstack/cinder and openstack/manila whose current
patch set has Zuul Verified -1, for every account in accounts.json marked "recheck": true.

Skips WIP changes and changes where anyone's recheck is newer than the last Zuul message (a run is
already in flight). Posts over SSH as sdodsley (key lives in WSL). Use --dry-run to only list.
"""
import subprocess
import sys

from gerrit_dashboard import get, load_accounts

PROJECTS = ["openstack/cinder", "openstack/manila"]  # exact names: specs and tempest plugins are excluded
SSH = ["wsl", "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=20", "-p", "29418", "sdodsley@review.opendev.org"]


def main():
    dry = "--dry-run" in sys.argv
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
        if c.get("work_in_progress"):
            print("skip WIP", c["_number"])
            continue
        ver = c.get("labels", {}).get("Verified", {}).get("all", [])
        if not any(v.get("name") == "Zuul" and v.get("value", 0) < 0 for v in ver):
            continue
        msgs = c.get("messages", [])
        last_zuul = max((m["date"] for m in msgs if m["author"].get("name") == "Zuul"), default="")
        last_re = max((m["date"] for m in msgs if m.get("message", "").strip().lower().endswith("recheck")), default="")
        if last_re and last_re > last_zuul:
            print("skip in flight", c["_number"])
            continue
        todo.append((c["_number"], c["current_revision_number"], c["owner"].get("name", "?"), c["subject"]))
    for n, ps, owner, subj in todo:
        if dry:
            print("DRY-RUN would recheck %d,%d [%s] %s" % (n, ps, owner, subj))
            continue
        r = subprocess.run(SSH + ["gerrit", "review", "-m", "recheck", "%d,%d" % (n, ps)], capture_output=True, text=True, timeout=120)
        print("recheck %d,%d [%s] %s -> %s" % (n, ps, owner, subj, "ok" if r.returncode == 0 else "FAILED " + r.stderr.strip()))
    print("%d change(s) %s" % (len(todo), "listed" if dry else "processed"))


if __name__ == "__main__":
    main()
