# OpenStack Patch Board

Nightly dashboard of open OpenDev Gerrit changes, published at
https://sdodsley.github.io/openstack-patch-board/ by the Windows scheduled task
`OpenStackPatchBoard` (02:07, `nightly.ps1`).

## Adding an account to track

Edit `accounts.json` and add an entry to the `accounts` list:

```json
{
  "label": "Alice",
  "username": "alice-gerrit",
  "emails": ["alice@example.com", "alice@otherdomain.com"],
  "recheck": false
}
```

- `label` is what the Account column and the account filter show.
- `username` is the Gerrit username (shown on the user's Gerrit profile). The numeric
  account id is looked up from it on every run; you may give `"id": 12345` instead.
- `emails` catches changes the person authored or committed but someone else owns
  (takeovers, backports pushed by a colleague). Optional.
- `recheck: true` includes that account's open **master** changes in `openstack/cinder`
  and `openstack/manila` in the nightly automatic `recheck` when Zuul votes -1. The
  recheck comment is posted from Simon's own Gerrit identity, so only enable this for
  people who are happy with that.

Then either wait for the 02:07 run or refresh by hand:

```powershell
python C:\Users\simon\gerrit-dashboard\gerrit_dashboard.py C:\Users\simon\gerrit-dashboard\dashboard.html
wsl bash /mnt/c/Users/simon/gerrit-dashboard/publish_pages.sh
```

`python recheck_master.py --dry-run` previews which changes would be rechecked.

## Files

| File | Purpose |
| --- | --- |
| `accounts.json` | Who to track (see above). |
| `gerrit_dashboard.py`, `template.html` | Build `dashboard.html` (artifact flavour) and `index.html` (standalone). |
| `recheck_master.py` | Nightly `recheck` on Zuul -1 master changes for accounts with `recheck: true`. |
| `publish_pages.sh` | Runs inside WSL: commit `index.html` to `/home/simon/openstack-patch-board` and push. |
| `setup_pages.sh` | One-off, idempotent repo and Pages setup. |
| `nightly.ps1`, `nightly.log` | The scheduled task and its log. |
| `history.json` | Per-night state counts for the trend line. |

"Needs reply" means an unresolved comment thread or a human -1; nothing else.
