$ErrorActionPreference = 'Continue'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $dir
$log = Join-Path $dir 'nightly.log'
# Under Task Scheduler Python would otherwise print in cp1252 and die on a non-Latin change subject,
# and wsl.exe would write its own diagnostics into the log as UTF-16 with embedded NULs.
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
$env:WSL_UTF8 = '1'
"=== $(Get-Date -Format s) ===" | Out-File $log -Append -Encoding utf8
$rc = 0

# 0. Recheck master changes (openstack/cinder, openstack/manila) whose Zuul vote is -1.
#    A failure here is logged and reflected in the exit code, but the dashboard is still built and published.
& python (Join-Path $dir 'recheck_master.py') 2>&1 | Out-File $log -Append -Encoding utf8
if ($LASTEXITCODE -ne 0) { "recheck step failed (exit $LASTEXITCODE); continuing" | Out-File $log -Append -Encoding utf8; $rc = 2 }

# 1. Rebuild dashboard.html (artifact flavour) and index.html (standalone) from Gerrit, read-only GETs.
& python (Join-Path $dir 'gerrit_dashboard.py') (Join-Path $dir 'dashboard.html') 2>&1 | Out-File $log -Append -Encoding utf8
if ($LASTEXITCODE -ne 0) { "generator failed" | Out-File $log -Append -Encoding utf8; exit 1 }

# 2. Publish index.html and the tooling to GitHub Pages. All GitHub work runs inside WSL, where gh holds the login.
& wsl bash /mnt/c/Users/simon/gerrit-dashboard/publish_pages.sh 2>&1 | Out-File $log -Append -Encoding utf8
if ($LASTEXITCODE -ne 0) { "pages publish failed" | Out-File $log -Append -Encoding utf8; exit 1 }
exit $rc
