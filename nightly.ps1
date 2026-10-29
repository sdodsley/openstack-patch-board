$ErrorActionPreference = 'Continue'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir
$log = Join-Path $dir 'nightly.log'
"=== $(Get-Date -Format s) ===" | Out-File $log -Append -Encoding utf8

# 0. Recheck master changes (openstack/cinder, openstack/manila) whose Zuul vote is -1.
& python (Join-Path $dir 'recheck_master.py') 2>&1 | Out-File $log -Append -Encoding utf8

# 1. Rebuild dashboard.html (artifact flavour) and index.html (standalone) from Gerrit, read-only GETs.
& python (Join-Path $dir 'gerrit_dashboard.py') (Join-Path $dir 'dashboard.html') 2>&1 | Out-File $log -Append -Encoding utf8
if ($LASTEXITCODE -ne 0) { "generator failed" | Out-File $log -Append -Encoding utf8; exit 1 }

# 2. Publish index.html to GitHub Pages. All GitHub work runs inside WSL, where gh holds the login.
& wsl bash /mnt/c/Users/simon/gerrit-dashboard/publish_pages.sh 2>&1 | Out-File $log -Append -Encoding utf8
if ($LASTEXITCODE -ne 0) { "pages publish failed" | Out-File $log -Append -Encoding utf8; exit 1 }
