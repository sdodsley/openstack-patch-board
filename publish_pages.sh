#!/bin/bash
# Nightly: push the regenerated dashboard to the GitHub Pages repo.
# Runs inside WSL (all GitHub work lives there; gh is the git credential helper).
set -euo pipefail
export PATH=/snap/bin:$PATH
# gh (the git credential helper) needs a writable XDG_RUNTIME_DIR; /run/user/1000 may not exist when
# the WSL VM is cold-started by the scheduled task.
export XDG_RUNTIME_DIR=/tmp/ghrt; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
SRC_DIR=/mnt/c/Users/simon/gerrit-dashboard
DEST=/home/simon/openstack-patch-board
# The repo carries the tooling as well as the generated page, so edits to the scripts or
# accounts.json are versioned by the next nightly run.
TOOLING="README.md LICENSE accounts.json gerrit_dashboard.py template.html recheck_master.py publish_pages.sh setup_pages.sh nightly.ps1"
[ -f "$SRC_DIR/index.html" ] || { echo "pages: no index.html to publish"; exit 1; }
[ -d "$DEST/.git" ] || { echo "pages: $DEST is not a git repo; run setup_pages.sh"; exit 1; }
cd "$DEST"
cp "$SRC_DIR/index.html" index.html
for f in $TOOLING; do
  if [ -f "$SRC_DIR/$f" ]; then cp "$SRC_DIR/$f" "$f"; fi
done
: > .nojekyll
chmod 644 index.html .nojekyll $TOOLING 2>/dev/null || true   # cp from /mnt/c sets the exec bit
git add -A
if git diff --cached --quiet; then echo "pages: no change"; exit 0; fi
stamp=$(grep -o '"generated": "[^"]*"' index.html | head -1 | cut -d'"' -f4)
git commit -q -m "Refresh ${stamp:-$(date -u +%F)}"
git push -q origin main
echo "pages: pushed (${stamp:-unknown})"
