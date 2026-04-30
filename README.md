# Phone Code

Code from your phone using a terminal and opencode on ephemeral AWS Fargate containers.

## Quick Start

```bash
# 1. Configure
cp config.example ~/.phone-code-config
# edit: PHONE_CODE_API_URL, PHONE_CODE_API_KEY, GITHUB_USER, GITHUB_TOKEN

# 2. Code from your phone
./phone-code my-project
```

That's it. SSH key generated automatically, container provisioned, repo cloned, opencode ready.

## Overview

Phone Code spins up a secure, ephemeral Fargate container with a pre-built Docker image containing git, opencode, and all necessary tools. Your phone only needs `ssh`, `ssh-keygen`, and `curl` — no AWS credentials, no heavy tooling.

```
phone terminal (curl + ssh only)
  │
  ├── 1. Generate ephemeral SSH key
  ├── 2. Request session via API (Lambda)
  │       └── Lambda provisions Fargate task with pubkey injected
  ├── 3. SSH into container → opencode session ready
  └── 4. On disconnect: container destroyed
```

### What the container provides
- Repo cloned from GitHub, session branch created (`mobile-YYYYMMDD-HHMMSS`)
- opencode with AI provider configured
- Auto-push to session branch every 5 minutes
- shellcheck, jq, and standard GNU tools

### Safety
- Ephemeral container — nothing persists after disconnect
- SSH key-only auth, generated fresh each session
- OpenCode API key in AWS Secrets Manager (never on phone)
- GitHub token scoped to repo push only

## Configuration

```bash
# ~/.phone-code-config
export PHONE_CODE_API_URL="https://api.example.com/sessions"
export PHONE_CODE_API_KEY="your-api-key"
export GITHUB_USER="your-github-username"
export GITHUB_TOKEN="github_pat_..."  # fine-grained PAT with repo push scope
```

### Infrastructure (one-time setup)

The AWS infrastructure (ECR, ECS Fargate cluster, Lambda, API Gateway, Secrets Manager, IAM) is defined in `infra/` as Terraform:

```bash
cd infra
terraform init
terraform apply
```

Store your opencode API key in Secrets Manager:

```bash
aws secretsmanager put-secret-value \
  --secret-id phone-code/opencode-api-key \
  --secret-string '{"OPENCODE_API_KEY":"sk-..."}'
```

Build and push the Docker image:

```bash
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URL
docker build -t phone-code .
docker tag phone-code:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

Or let GitHub Actions handle it — see `.github/workflows/deploy.yml`.

## Usage

```bash
./phone-code my-project        # Start a session
./phone-code my-org/a-repo    # Org repo
./phone-code --stop            # Tear down current session
```

The script:
1. Generates an ephemeral ed25519 SSH key
2. Sends pubkey + project name to the session broker API
3. Waits for container ready
4. Opens SSH connection — you land in opencode
5. On disconnect: container is destroyed

## Development Workflow

Bash-based CLI project — no Makefile, package.json, or build system.

```bash
# Test
./test.sh

# Lint
shellcheck *.sh

# Create PR (draft first)
gh pr create --draft --title "Description" --body "## Summary\n- Changes"

# Monitor CI
gh pr checks <PR-NUMBER>

# Ready for review
gh pr ready <PR-NUMBER>
```

### Docker image

```bash
docker build -t phone-code .
docker run -e PUBKEY="$(cat /tmp/test.pub)" -e PROJECT="test" -e GITHUB_USER="me" -e GITHUB_TOKEN="ghp_..." -p 2222:2222 phone-code
```

### Lambda

```bash
cd session-broker
npm install
# deploy via Terraform or manually: zip + aws lambda update-function-code
```

## Architecture

```
├── phone-code              # Local script: keygen → curl API → ssh → cleanup
├── Dockerfile              # ubuntu:22.04 + git + sshd + opencode + shellcheck
├── entrypoint.sh           # Container startup: pubkey → sshd → clone → opencode
├── session-broker/         # Lambda: POST /sessions, DELETE /sessions/{id}
├── infra/                  # Terraform: ECR, ECS, IAM, Secrets Manager, API Gateway
├── .github/workflows/      # CI: build image → push ECR → deploy
├── config.example
└── .agent/
```
