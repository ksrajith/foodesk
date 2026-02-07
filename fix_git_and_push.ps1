# Fix corrupted .git and push to GitHub
# Run from: D:\mobileGit\food_desk\food_desk

$projectPath = "D:\mobileGit\food_desk\food_desk"
Set-Location $projectPath

# 1. Remove the corrupted .git folder (force)
if (Test-Path ".git") {
    Remove-Item -Recurse -Force .git
    Write-Host "Removed old .git folder."
}

# 2. Initialize fresh repo
git init
if ($LASTEXITCODE -ne 0) { exit 1 }

# 3. Add remote
git remote add origin https://github.com/ksrajith/food_desk.git
if ($LASTEXITCODE -ne 0) { Write-Host "Remote may already exist. Run: git remote set-url origin https://github.com/ksrajith/food_desk.git"; exit 1 }

# 4. Stage and commit
git add .
git commit -m "Initial commit: FoodDesk meal ordering app"
if ($LASTEXITCODE -ne 0) { exit 1 }

# 5. Set main branch and push
git branch -M main
git push -u origin main

Write-Host "Done. If push asked for login, use your GitHub username and a Personal Access Token as password."
