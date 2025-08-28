# 🔒 Branch Protection Setup for Message Publisher

## GitHub Branch Protection Rules

To protect the `main` branch from direct pushes and enforce pull request workflows, follow these steps:

### 1. Navigate to Repository Settings
1. Go to your GitHub repository
2. Click on **Settings** tab
3. Click on **Branches** in the left sidebar

### 2. Add Branch Protection Rule
1. Click **Add rule**
2. In **Branch name pattern**, enter: `main`

### 3. Configure Protection Settings

#### ✅ **Restrict pushes that create files**
- [x] **Require a pull request before merging**
  - [x] Require approvals: `1` (minimum)
  - [x] Dismiss stale pull request approvals when new commits are pushed
  - [x] Require review from code owners (if you have CODEOWNERS file)

#### ✅ **Require status checks to pass**
- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date before merging
  - Add status checks:
    - `ci/jenkins` (Jenkins pipeline)
    - `eslint` (ESLint checks)
    - `build` (Build verification)

#### ✅ **Additional Restrictions**
- [x] **Require linear history** (optional - keeps git history clean)
- [x] **Include administrators** (applies rules to admin users too)
- [x] **Restrict pushes that create files** (prevents direct pushes)
- [x] **Allow force pushes** ❌ (disabled for security)
- [x] **Allow deletions** ❌ (prevents accidental branch deletion)

### 4. Alternative: Using GitHub CLI

```bash
# Install GitHub CLI if not already installed
# https://cli.github.com/

# Create branch protection rule
gh api repos/:owner/:repo/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["ci/jenkins","eslint","build"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false
```

## 🔄 Workflow After Setup

1. **Developer Flow:**
   ```bash
   # Create feature branch
   git checkout -b feature/new-feature
   
   # Make changes and commit
   git add .
   git commit -m "feat: add new feature"
   
   # Push to feature branch
   git push origin feature/new-feature
   
   # Create pull request through GitHub UI
   ```

2. **Pull Request Process:**
   - Jenkins pipeline runs automatically
   - ESLint checks must pass
   - Build must succeed
   - At least 1 review approval required
   - All status checks must be green
   - Then merge is allowed

3. **Main Branch Deployment:**
   - Merge to main triggers production Jenkins pipeline
   - Docker images built and versioned
   - Deployment to production environment

## 📋 Required Files

The following files should exist in your repository for complete CI/CD:

- `.github/workflows/` (if using GitHub Actions as backup)
- `Jenkinsfile` (Jenkins pipeline configuration)
- `.eslintrc.js` (ESLint configuration)
- `Dockerfile` files for each service
- `docker-compose.yml` (for local development)

## 🚨 Important Notes

1. **Emergency Procedures:**
   - Admin users can bypass protections in emergencies
   - Document any bypass usage
   - Create follow-up PR to fix issues properly

2. **Status Checks:**
   - Jenkins webhook must be configured
   - ESLint must be properly configured in all packages
   - Build scripts must return proper exit codes

3. **Review Requirements:**
   - Assign code owners for critical paths
   - Require reviews from team leads for major changes
   - Use draft PRs for work-in-progress

This setup ensures code quality, prevents direct pushes to main, and maintains a clean git history.