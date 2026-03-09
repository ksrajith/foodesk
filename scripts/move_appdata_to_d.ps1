# Run this script as Administrator AFTER closing all applications (Cursor, Chrome, Android Studio, etc.)
# Best: restart PC, log in, then run this script before opening any app.
# This moves C:\Users\DELL\AppData to D:\cusr_moved\AppData and creates a junction so apps still work.

$ErrorActionPreference = "Stop"
$userProfile = "C:\Users\DELL"
$appDataSrc = "$userProfile\AppData"
$appDataDest = "D:\cusr_moved\AppData"

if (-not (Test-Path $appDataSrc)) {
    Write-Host "AppData not found at $appDataSrc" -ForegroundColor Red
    exit 1
}

$link = Get-Item $appDataSrc -Force -ErrorAction SilentlyContinue
if ($link.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    Write-Host "AppData is already a junction (already moved). Nothing to do." -ForegroundColor Green
    exit 0
}

if (Test-Path $appDataDest) {
    Write-Host "Destination $appDataDest already exists. Remove it first or use a different path." -ForegroundColor Red
    exit 1
}

Write-Host "Moving AppData to D: drive (this may take several minutes)..." -ForegroundColor Yellow
Move-Item -Path $appDataSrc -Destination $appDataDest -Force

Write-Host "Creating junction so apps still use C:\Users\DELL\AppData..." -ForegroundColor Yellow
New-Item -ItemType Junction -Path $appDataSrc -Target $appDataDest -Force | Out-Null

Write-Host "Done. AppData is now on D: drive. You can open your apps." -ForegroundColor Green
