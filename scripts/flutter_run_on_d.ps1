# Run Flutter with Pub cache on D: to avoid "different roots" when project is on D: and cache on C:
# Use: .\scripts\flutter_run_on_d.ps1   (from project root)
$ProjectRoot = $PSScriptRoot | Split-Path -Parent
$PubCache = "D:\pub_cache"
if (-not (Test-Path $PubCache)) { New-Item -ItemType Directory -Path $PubCache -Force | Out-Null }
$env:PUB_CACHE = $PubCache
Set-Location $ProjectRoot
Write-Host "PUB_CACHE=$PubCache (same drive as project to avoid Kotlin 'different roots' error)"
& flutter pub get
& flutter run $args
