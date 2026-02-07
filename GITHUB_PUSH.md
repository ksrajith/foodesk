# Push FoodDesk to GitHub (ksrajith)

Follow these steps in a terminal (PowerShell or Command Prompt).

## 0. If you get "could not lock config file" or "not a git repository"

Your `.git` folder is corrupted or partial. Remove it and start fresh:

```powershell
cd D:\mobileGit\food_desk\food_desk
Remove-Item -Recurse -Force .git
```

Then continue from **section 3** below (skip "Create repository" if you already did it).

---

## 1. Create a new repository on GitHub

1. Go to **https://github.com/new**
2. Sign in as **ksrajith**
3. Repository name: **food_desk** (or `food-desk`)
4. Choose **Public**, leave "Add a README" **unchecked**
5. Click **Create repository**

## 2. Open terminal in the project folder

```powershell
cd D:\mobileGit\food_desk\food_desk
```

## 3. Initialize Git (if not already)

```powershell
git init
```

## 4. Add your GitHub remote

Use the repo name you created in step 1. Example if the repo is `food_desk`:

```powershell
git remote add origin https://github.com/ksrajith/food_desk.git
```

If you named it something else (e.g. `food-desk`), use:

```powershell
git remote add origin https://github.com/ksrajith/food-desk.git
```

## 5. Stage all files

```powershell
git add .
```

## 6. First commit

```powershell
git commit -m "Initial commit: FoodDesk meal ordering app"
```

## 7. Push to GitHub

For a new repo with no history, use:

```powershell
git branch -M main
git push -u origin main
```

If GitHub created the repo with a default branch named `master`:

```powershell
git push -u origin main
```

(or `git push -u origin master` if your branch is `master`)

---

**If you already have a remote** (e.g. from a different folder), check and update:

```powershell
git remote -v
git remote set-url origin https://github.com/ksrajith/food_desk.git
```

**If Git asks for credentials**, use a [Personal Access Token](https://github.com/settings/tokens) as the password when prompted (username = ksrajith).
