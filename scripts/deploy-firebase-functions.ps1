# Deploy Firebase Functions using Node at D:\node_donot_del
# Uses npx (no global firebase-tools install needed). Run from project root: .\scripts\deploy-firebase-functions.ps1

$NodeDir = "D:\node_donot_del"
$Npm = Join-Path $NodeDir "npm.cmd"
$Npx = Join-Path $NodeDir "npx.cmd"
$ProjectRoot = $PSScriptRoot | Split-Path -Parent

if (-not (Test-Path $Npm)) {
    Write-Error "npm not found at $Npm. Check Node path."
    exit 1
}

# So npm/npx and firebase (and its child processes) can find node
$env:Path = "$NodeDir;$env:Path"

Set-Location $ProjectRoot

# Install firebase-tools locally at project root (avoids broken global install)
if (-not (Test-Path (Join-Path $ProjectRoot "node_modules\firebase-tools"))) {
    Write-Host "Installing firebase-tools locally..."
    & $Npm install
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Installing function dependencies..."
Set-Location (Join-Path $ProjectRoot "functions")
& $Npm install
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploying Firebase functions..."
Set-Location $ProjectRoot
& $Npx firebase deploy --only functions
exit $LASTEXITCODE
