# 👥 Team GitHub Workflow – Simple Guide

### 📌 Goal:
> Everyone works **together** on the same project **without breaking** each other's work.

---

## ✅ Step-by-Step for Every Developer

### 1️⃣ Clone the Project (First Time Only)

```bash
git clone https://github.com/DanialShah11/cvapp.git
cd cvapp
```
### 2️⃣ Always Pull Latest Code Before Starting

```bash
git checkout main
git pull origin main
```
> ⚠️ This makes sure your code is up to date before you begin.

### 3️⃣ Create a New Branch for Your Task

```bash
git checkout -b feature/your-task-name
```
> Example: feature/login-screen or fix/pdf-bug
> Everyone should have their own branch

### 4️⃣ Do Your Work, Then Save It

```bash
git add .
git commit -m "feat: added login screen"
```
> Write a short, clear message about what you did.

### 5️⃣ Push Your Branch to GitHub

```bash
git push origin feature/your-task-name
```

### 6️⃣ Open a Pull Request (PR)

1. Go to GitHub → Your Repo

2. Click "Compare & Pull Request"

3. Add a title and description

4. Submit the Pull Request

> 💬 Your team can review and merge it to main when ready.

### 7️⃣ After Merge → Delete Old Branch

```bash
git checkout main
git pull origin main
git branch -d feature/your-task-name
```

> This keeps everything clean.

## 🔁 Everyday Workflow Summary

```bash
git checkout main
git pull origin main

git checkout -b feature/your-work

# Do your work

git add .
git commit -m "feat: added something"
git push origin feature/your-work

# Open Pull Request on GitHub
```

### ❗ What NOT to Do
❌ Don’t Do This	:
Don’t push to main,	
Don’t work on old code,	
Don’t ignore errors,	
Don’t push secrets.	

✅ Do This Instead:
Use your own branch,
Pull latest changes first,
Test your code before PR,
google-services.json is ignored ✅


### 🧠 Simple Commit Message Tips
Use clear prefixes:

| Prefix      | Use for...               |
| ----------- | ------------------------ |
| `feat:`     | New features             |
| `fix:`      | Bug fixes                |
| `refactor:` | Code cleanup/refactoring |
| `docs:`     | Documentation changes    |
| `style:`    | UI or styling tweaks     |


Example:
git commit -m "feat: created CV preview screen"



