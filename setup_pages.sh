#!/bin/bash
# One-off (idempotent): create the private GitHub Pages repo, seed it with the current dashboard,
# enable Pages from main:/ . Runs inside WSL, where gh holds the GitHub login.
set -euo pipefail
export PATH=/snap/bin:$PATH
# gh (the git credential helper) needs a writable XDG_RUNTIME_DIR; /run/user/1000 may not exist when
# the WSL VM is cold-started by the scheduled task.
export XDG_RUNTIME_DIR=/tmp/ghrt; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export GIT_TERMINAL_PROMPT=0
OWNER=sdodsley
REPO=openstack-patch-board
SRC=/mnt/c/Users/simon/gerrit-dashboard
DEST=/home/simon/$REPO

if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  echo "repo exists: $OWNER/$REPO"
else
  gh repo create "$OWNER/$REPO" --private --description "Nightly dashboard of open OpenStack Gerrit changes" --disable-issues --disable-wiki
  echo "repo created: $OWNER/$REPO (private)"
fi

if [ ! -d "$DEST/.git" ]; then
  git init -q -b main "$DEST"
  git -C "$DEST" remote add origin "https://github.com/$OWNER/$REPO.git"
fi
cp "$SRC/index.html" "$DEST/index.html"
: > "$DEST/.nojekyll"
chmod 644 "$DEST/index.html" "$DEST/.nojekyll"   # cp from /mnt/c sets the exec bit
cd "$DEST"
git add -A
if ! git diff --cached --quiet; then
  git commit -q -F - <<MSG
Seed the OpenStack patch board

Generated nightly by C:/Users/simon/gerrit-dashboard/nightly.ps1.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
fi
git push -q -u origin main
echo "pushed main"

if gh api "repos/$OWNER/$REPO/pages" >/dev/null 2>&1; then
  echo "pages already enabled"
else
  gh api -X POST "repos/$OWNER/$REPO/pages" -f build_type=legacy -f 'source[branch]=main' -f 'source[path]=/' >/dev/null
  echo "pages enabled"
fi
gh api "repos/$OWNER/$REPO/pages" --jq '"pages url: " + .html_url + "  status: " + (.status // "pending")'
