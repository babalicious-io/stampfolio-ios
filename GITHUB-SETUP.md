# GitHub Setup Guide for Philately iOS App

Your Git repository is initialized and ready! Follow these steps to connect it to GitHub.

## ✅ What's Already Done

- ✅ Git repository initialized
- ✅ iOS-specific `.gitignore` created
- ✅ Initial commit made with all Cursor rules
- ✅ Default branch set to `main`
- ✅ Git user configured (babalicious-io)

## 🚀 Connect to GitHub

### Option 1: Using GitHub CLI (Recommended)

If you have `gh` CLI installed:

```bash
# Create a new repository on GitHub and push
gh repo create philately-ios --private --source=. --remote=origin --push

# Or for public repository
gh repo create philately-ios --public --source=. --remote=origin --push
```

### Option 2: Using GitHub Web Interface

#### Step 1: Create a New Repository on GitHub

1. Go to [https://github.com/new](https://github.com/new)
2. Repository name: `philately-ios` (or your preferred name)
3. Description: "iOS app for stamp collectors built with SwiftUI"
4. Choose **Private** or **Public**
5. **DO NOT** initialize with README, .gitignore, or license (we already have these!)
6. Click "Create repository"

#### Step 2: Connect Your Local Repository

GitHub will show you commands. Use the "push an existing repository" section:

```bash
# Add the remote repository
git remote add origin https://github.com/YOUR_USERNAME/philately-ios.git

# Verify the remote was added
git remote -v

# Push your code to GitHub
git push -u origin main
```

**Replace `YOUR_USERNAME`** with your actual GitHub username!

#### Step 3: Verify on GitHub

1. Refresh your GitHub repository page
2. You should see all 30 files including:
   - `.cursor/rules/` (24 rule files)
   - `README.md`
   - `.gitignore`
   - `CURSOR-RULES.md`

## 🔐 Authentication Options

### HTTPS Authentication

If prompted for credentials:
- **Username**: Your GitHub username
- **Password**: Use a Personal Access Token (not your GitHub password!)

**Create a token:**
1. Go to: Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (full control)
4. Copy the token and use it as your password

### SSH Authentication (Recommended for Frequent Use)

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "baba@babalicious.io"

# Add SSH key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub

# Add to GitHub: Settings → SSH and GPG keys → New SSH key
# Then use SSH URL instead:
git remote set-url origin git@github.com:YOUR_USERNAME/philately-ios.git
```

## 📋 Next Steps After Pushing to GitHub

### 1. Set Up Branch Protection Rules

Protect your `main` branch:
1. Go to: Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require a pull request before merging
   - ✅ Require status checks to pass
   - ✅ Require linear history

### 2. Create Development Branch

```bash
# Create and switch to develop branch
git checkout -b develop

# Push develop branch
git push -u origin develop

# Now create feature branches from develop
git checkout -b feature/stamp-collection
```

### 3. Set Up GitHub Actions (Optional)

Create `.github/workflows/ios.yml` for CI/CD:

```yaml
name: iOS CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build-and-test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_16.0.app
    
    - name: Build
      run: xcodebuild build -scheme Philately -destination 'platform=iOS Simulator,name=iPhone 15'
    
    - name: Run tests
      run: xcodebuild test -scheme Philately -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 4. Add Issue Templates

Create `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md` for better issue tracking.

### 5. Add Pull Request Template

Create `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Description
<!-- Describe your changes -->

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] UI tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows Swift style guidelines (@with-swift)
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings
```

## 🎯 Recommended Workflow

### Daily Development

```bash
# 1. Pull latest changes
git pull origin main

# 2. Create feature branch
git checkout -b feature/your-feature

# 3. Make changes and commit (use @create-commit-message rule!)
git add .
git commit -m "feat: add stamp detail view"

# 4. Push to GitHub
git push origin feature/your-feature

# 5. Create Pull Request on GitHub
# 6. Review, merge, and delete branch
```

### Using Cursor Rules for Commits

Ask Cursor to generate conventional commit messages:
```
"Generate a commit message for the stamp collection feature I just added @create-commit-message"
```

## 🔍 Verify Your Setup

Run these commands to verify everything is set up correctly:

```bash
# Check git status
git status

# Check remote
git remote -v

# Check commit history
git log --oneline

# Check branch
git branch
```

Expected output:
- Status: Clean working directory
- Remote: origin pointing to your GitHub repository
- Log: Shows your initial commit
- Branch: * main (active branch)

## 📚 Resources

- [GitHub Docs](https://docs.github.com)
- [Git Best Practices](https://git-scm.com/book/en/v2)
- [Conventional Commits](https://www.conventionalcommits.org)
- [iOS CI/CD with Fastlane](https://docs.fastlane.tools)

## 🆘 Troubleshooting

### "fatal: remote origin already exists"
```bash
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/philately-ios.git
```

### Authentication Failed
```bash
# Use Personal Access Token as password, not your GitHub password
# Or switch to SSH authentication
```

### Push Rejected
```bash
# Pull first, then push
git pull origin main --rebase
git push origin main
```

---

**Ready to push to GitHub?** Run the commands in Option 2, Step 2 above! 🚀
