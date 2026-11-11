# Kujenga web app na kuipakia kwenye server (Windows PowerShell, kwenye kompyuta yenye Flutter).
#   cd C:\...\logistic_app
#   powershell -ExecutionPolicy Bypass -File deploy\upload_web.ps1 -Server user@SERVER_IP
# Web inatumia API ya domain ile ile iliyoifungua (https://<domain>/api) - haihitaji API_SERVER.
param(
    [Parameter(Mandatory = $true)][string]$Server,
    [string]$WebDir = "/var/www/logistic/web"
)
$ErrorActionPreference = "Stop"

flutter build web --release
if ($LASTEXITCODE -ne 0) { throw "flutter build web imeshindikana" }

$tgz = Join-Path $env:TEMP "logistic_web.tgz"
if (Test-Path $tgz) { Remove-Item $tgz }
tar -czf $tgz -C build/web .                      # tar ipo Windows 10/11
scp $tgz "${Server}:/tmp/logistic_web.tgz"
if ($LASTEXITCODE -ne 0) { throw "scp imeshindikana" }

$remote = "set -e; rm -rf '$WebDir.new'; mkdir -p '$WebDir.new'; tar -xzf /tmp/logistic_web.tgz -C '$WebDir.new'; " +
          "rm -rf '$WebDir.old'; [ -d '$WebDir' ] && mv '$WebDir' '$WebDir.old'; mv '$WebDir.new' '$WebDir'; " +
          "chmod -R a+rX '$WebDir'; rm -f /tmp/logistic_web.tgz"
ssh $Server $remote
if ($LASTEXITCODE -ne 0) { throw "kuweka web kwenye server kumeshindikana" }
Write-Host "Web app imepakiwa." -ForegroundColor Green
