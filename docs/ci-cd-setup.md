# CI/CD Setup Guide

Complete guide for setting up GitHub Actions CI/CD pipeline with AWS OIDC.

## Overview

The CI/CD pipeline provides:
- ✅ Automatic format checking and validation
- ✅ Terraform plan on pull requests (with PR comments)
- ✅ Terraform apply on merge to main
- ✅ Manual terraform destroy workflow
- ✅ OIDC authentication (no AWS keys needed)

## Prerequisites

- [ ] GitHub repository created
- [ ] Code pushed to GitHub
- [ ] AWS account with admin access
- [ ] Terraform infrastructure partially deployed (to create OIDC resources)

## Step-by-Step Setup

### Step 1: Update GitHub Repository Information

Edit `iam-github-actions.tf` and update line 45:

```hcl
# Change from:
"token.actions.githubusercontent.com:sub" = "repo:*:*"  # CHANGE THIS!

# To (replace with your actual repo):
"token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"

# Example:
"token.actions.githubusercontent.com:sub" = "repo:vinic/aws-terraform:*"
```

### Step 2: Deploy OIDC Resources

```bash
# Initialize Terraform (if not done already)
terraform init

# Plan - verify OIDC resources will be created
terraform plan

# Apply - create OIDC provider and role
terraform apply

# Get the role ARN (save this for next step)
terraform output github_actions_role_arn
```

**Expected output:**
```
github_actions_role_arn = "arn:aws:iam::123456789012:role/github-actions-terraform-role"
```

### Step 3: Add GitHub Secrets

Go to your GitHub repository:

1. **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add the following secrets:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `AWS_ROLE_ARN` | ARN from Step 2 | `arn:aws:iam::123456789012:role/github-actions-terraform-role` |
| `AWS_REGION` | Your AWS region | `us-east-1` |

### Step 4: (Optional) Create GitHub Environments for Protection

For production-grade security with approval workflows:

1. Go to **Settings** → **Environments**
2. Click **New environment**

**Create "production" environment:**
- Name: `production`
- Protection rules:
  - ✅ Required reviewers: Add yourself (or team)
  - ⏱️ Wait timer: 0 minutes (optional: add delay)
- Click **Save protection rules**

**Create "destroy" environment:**
- Name: `destroy`
- Protection rules:
  - ✅ Required reviewers: Add yourself
- Click **Save protection rules**

**Then uncomment these lines in `.github/workflows/terraform.yml`:**

Line 141:
```yaml
environment: production  # Uncomment this line
```

Line 186:
```yaml
environment: destroy  # Uncomment this line
```

### Step 5: Test the Workflow

**Test Format Check:**
```bash
# Create a test branch
git checkout -b test/ci-setup

# Make a small change
echo "# CI/CD Test" >> README.md

# Push
git add .
git commit -m "test: CI/CD setup"
git push origin test/ci-setup
```

**Expected:** GitHub Actions should run `terraform-check` job

**Test Plan on PR:**
```bash
# Create a pull request via GitHub UI or CLI
gh pr create --title "Test CI/CD" --body "Testing GitHub Actions workflow"
```

**Expected:**
- ✅ Format check passes
- ✅ Validation passes
- 📝 Terraform plan posted as PR comment

**Test Apply (merge to main):**
```bash
# Merge the PR
gh pr merge --squash

# Or via GitHub UI
```

**Expected:**
- ✅ Workflow runs `terraform-apply` job
- ⏱️ Waits for approval (if environment protection enabled)
- ✅ Applies infrastructure changes

### Step 6: Verify CI/CD is Working

Check the **Actions** tab in your GitHub repository:

```
✅ Terraform CI/CD
   ├─ ✅ terraform-check (2m 14s)
   ├─ ✅ terraform-plan (3m 42s)
   └─ ✅ terraform-apply (5m 18s)
```

## Workflow Triggers

### terraform-check
**Triggers:** All pushes and PRs that change `.tf` or `.tfvars` files

**What it does:**
- Checks Terraform formatting (`terraform fmt -check`)
- Validates Terraform configuration
- Comments on PR if format check fails

### terraform-plan
**Triggers:** Pull requests only

**What it does:**
- Runs `terraform plan` with dev environment
- Uploads plan as artifact
- Posts plan output as PR comment
- Fails if plan errors

### terraform-apply
**Triggers:** Push to `main` branch only

**What it does:**
- Runs `terraform plan` and `terraform apply`
- Uploads outputs as artifact
- Requires approval if environment protection is enabled

### terraform-destroy
**Triggers:** Manual workflow dispatch only

**What it does:**
- Destroys all infrastructure
- Requires approval if environment protection is enabled

**To trigger:**
```bash
# Via GitHub UI: Actions → Terraform CI/CD → Run workflow → Select branch

# Or via CLI:
gh workflow run terraform.yml
```

## Troubleshooting

### Error: "Credentials could not be loaded"

**Cause:** OIDC role ARN not configured or incorrect

**Fix:**
1. Verify `AWS_ROLE_ARN` secret is set correctly
2. Check the role exists: `aws iam get-role --role-name github-actions-terraform-role`
3. Verify trust policy allows your repository

### Error: "Repository is not allowed"

**Cause:** Repository name in trust policy doesn't match

**Fix:**
1. Edit `iam-github-actions.tf`
2. Update line 45 with correct repository name
3. Apply changes: `terraform apply`

### Error: "Environment not found"

**Cause:** GitHub environment doesn't exist

**Fix:**
1. Create the environment in GitHub Settings → Environments
2. Or comment out `environment:` line in workflow

### Format Check Fails

**Fix:**
```bash
# Format all Terraform files
terraform fmt -recursive

# Commit and push
git add .
git commit -m "fix: format terraform files"
git push
```

### Plan Fails

**Check:**
1. Backend is configured correctly
2. AWS credentials are valid
3. All required variables are set
4. No syntax errors in `.tf` files

**Debug:**
```bash
# Run plan locally
terraform init
terraform plan -var-file=environments/dev.tfvars
```

### Apply Fails

**Common causes:**
1. AWS quota limits
2. Resource already exists
3. Invalid container image (for ECS)
4. Missing permissions

**Debug:**
1. Check GitHub Actions logs
2. Look for specific error message
3. Run `terraform plan` locally to verify

## Workflow Customization

### Change Environment for Apply

Edit `.github/workflows/terraform.yml` line 164:

```yaml
# Change from dev to staging or prod
terraform plan -var-file=environments/staging.tfvars -out=tfplan
```

### Add Slack Notifications

Add to workflow:

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Add Cost Estimation

Add before plan:

```yaml
- name: Setup Infracost
  uses: infracost/actions/setup@v2

- name: Generate Infracost estimate
  run: |
    infracost breakdown --path . \
      --terraform-var-file=environments/dev.tfvars
```

### Run Tests Before Apply

Add before apply:

```yaml
- name: Run Terraform Tests
  run: terraform test
```

## Security Best Practices

1. **Never commit AWS credentials** - Use OIDC only
2. **Use environment protection** for production
3. **Require PR reviews** before merge to main
4. **Enable branch protection** on main branch
5. **Rotate OIDC roles** periodically
6. **Audit GitHub Actions logs** regularly
7. **Use least privilege** IAM policies

## Branch Protection (Recommended)

Set up branch protection for `main`:

1. Go to **Settings** → **Branches**
2. Add rule for `main` branch
3. Enable:
   - ✅ Require pull request before merging
   - ✅ Require status checks to pass (terraform-check, terraform-plan)
   - ✅ Require conversation resolution
   - ✅ Do not allow bypassing

## Manual Workflow Dispatch

To manually trigger a workflow:

**Via GitHub UI:**
1. Go to **Actions** tab
2. Select **Terraform CI/CD** workflow
3. Click **Run workflow**
4. Select branch
5. Click **Run workflow** button

**Via GitHub CLI:**
```bash
# Run workflow on current branch
gh workflow run terraform.yml

# Run on specific branch
gh workflow run terraform.yml --ref feature-branch
```

## Monitoring

**View workflow runs:**
```bash
# List recent runs
gh run list --workflow=terraform.yml

# View specific run
gh run view <run-id>

# Watch run in real-time
gh run watch
```

**Download artifacts:**
```bash
# List artifacts
gh run view <run-id>

# Download plan
gh run download <run-id> -n terraform-plan

# Download outputs
gh run download <run-id> -n terraform-outputs
```

## Cost Considerations

GitHub Actions is free for public repositories with limits:
- 2,000 minutes/month (Linux runners)
- Unlimited for public repos

For private repositories:
- Free tier: 2,000 minutes/month
- Cost: $0.008/minute for Linux

**Typical usage:**
- terraform-check: ~2 minutes
- terraform-plan: ~3 minutes
- terraform-apply: ~5 minutes

**Monthly estimate (10 deployments):**
- 10 × (2 + 3 + 5) = 100 minutes
- Well within free tier

## Next Steps

1. ✅ Complete OIDC setup
2. ✅ Add GitHub secrets
3. ✅ Test workflow with PR
4. ✅ Enable environment protection (optional)
5. ✅ Set up branch protection
6. 📝 Document your CI/CD process
7. 🔔 Add notifications (Slack, email)
8. 📊 Add cost estimation (Infracost)

## Support

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS OIDC Guide](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
