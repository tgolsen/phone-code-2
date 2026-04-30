# Anchors

## Project Identity
- **Name**: Phone Code
- **Type**: Bash CLI tool + Node.js Lambda + Docker + Terraform
- **Purpose**: Single command from phone terminal → ephemeral Fargate container → opencode
- **Key files**: `phone-code` (local client), `Dockerfile` + `entrypoint.sh` (container image), `session-broker/` (Lambda), `infra/` (Terraform)

## AWS Environment
- **Account**: 144600480929
- **Profile**: `phone-code` (IAM user: `phone-code-deploy`)
- **Region**: `us-west-2`
- **AWS CLI**: Always prefix with `AWS_PROFILE=phone-code` or set env var

```bash
# Verify identity
AWS_PROFILE=phone-code aws sts get-caller-identity

# Deploy infra
cd infra && AWS_PROFILE=phone-code terraform apply

# Push image
AWS_PROFILE=phone-code aws ecr get-login-password | docker login --username AWS --password-stdin 144600480929.dkr.ecr.us-west-2.amazonaws.com
```

## Development Commands (CRITICAL — don't guess)

```bash
# Test
./test.sh

# Lint bash scripts
shellcheck *.sh entrypoint.sh

# Lint Lambda
cd session-broker && npm run lint 2>/dev/null || node -c index.js

# Terraform formatting
terraform fmt -check infra/

# Build Docker image locally
docker build -t phone-code .

# Run container locally (test)
docker run -e PUBKEY="$(cat ~/.ssh/id_ed25519.pub)" -e PROJECT="test" -e GITHUB_USER="tgolsen" -p 2222:2222 phone-code
```

## Architecture

```
phone terminal (curl + ssh only)
  │
  ├── 1. ssh-keygen → ephemeral ed25519 key
  ├── 2. curl POST API → Lambda (session-broker)
  │       └── Lambda → ecs.runTask (Fargate, public IP, SG:2222)
  │       └── Container entrypoint: write pubkey → sshd → clone repo → session branch → opencode
  ├── 3. ssh → opencode session
  ├── 4. Auto-push to mobile-YYYYMMDD-HHMMSS
  └── 5. On exit → curl DELETE API → Lambda → ecs.stopTask
```

## Git Workflow
- **Never** use `git add .` or `git add -A` — use `git add <specific-file>` or `git add -p`
- Branches: `mobile-YYYYMMDD-HHMMSS` (auto-created in container)
- Auto-push runs every 5 minutes inside the container
- **Never commit:** `.env`, config files with secrets, `*.key`, `*.pem`, `.terraform/`

## CLI Tools (Pre-Authorized)

### GitHub CLI (gh)
```bash
gh pr create --draft --title "Description" --body "## Summary\n- bullet points"
gh pr checks <PR-NUMBER>
gh pr ready <PR-NUMBER>
```

### Atlassian CLI (acli)
```bash
acli jira workitem view KEY-XXXX
acli jira workitem transition --key KEY-XXXX --status "In Progress"
```

## Permissions
- **Authorized**: Code development, branch ops, PR creation, CI monitoring, Jira transitions
- **NOT authorized**: Merging PRs, deployments, branch deletion (without explicit permission)

## Current Status
- **Docker image**: DEFINED — Dockerfile + entrypoint.sh
- **Lambda**: DEFINED — session-broker (POST/GET/DELETE)
- **Terraform**: DEFINED — ECR, ECS, IAM, Secrets Manager, API Gateway, Lambda
- **Local client**: DEFINED — phone-code script (keygen → API → SSH → cleanup)
- **GHA workflow**: DEFINED — build image → push ECR → deploy Lambda
- **Infra deployed**: NOT YET — need to run `terraform apply`
- **Image pushed**: NOT YET — need GHA run or manual push
- **End-to-end tested**: NOT YET