#!/bin/bash
set -e

PUBKEY="${PUBKEY:?PUBKEY required}"
PROJECT="${PROJECT:?PROJECT required}"
GITHUB_USER="${GITHUB_USER:?GITHUB_USER required}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
BRANCH_NAME="mobile-$(date +%Y%m%d-%H%M%S)"
OPENCODE_SECRET_ARN="${OPENCODE_SECRET_ARN:-}"
REPO_URL="https://${GITHUB_USER}@github.com/${GITHUB_USER}/${PROJECT}.git"

echo "=== Phone Code Container ==="
echo "Project: $PROJECT"
echo "Branch:  $BRANCH_NAME"

# Write pubkey for SSH access
echo "$PUBKEY" > /home/phonecoder/.ssh/authorized_keys
chmod 600 /home/phonecoder/.ssh/authorized_keys
chown phonecoder:phonecoder /home/phonecoder/.ssh/authorized_keys

# Start sshd FIRST — keep it running no matter what
/usr/sbin/sshd
sleep 2
echo "SSHD running on port 2222"

# Clone or pull repo — NOT fatal if it fails
REPO_OK=0
cd /workspace
if [ -d "$PROJECT/.git" ]; then
    echo "Pulling existing repo..."
    git -C "$PROJECT" fetch origin 2>&1 || echo "  (fetch failed, continuing)"
    git -C "$PROJECT" checkout main 2>/dev/null || git -C "$PROJECT" checkout master 2>/dev/null || true
    git -C "$PROJECT" pull 2>&1 || echo "  (pull failed, continuing)"
    REPO_OK=1
else
    echo "Cloning repo..."
    if [ -n "$GITHUB_TOKEN" ]; then
        git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${PROJECT}.git" 2>&1 && REPO_OK=1 || {
            echo "  Clone failed. Check that the repo exists and your token has access."
            echo "  You can clone manually after connecting via SSH."
        }
    else
        git clone "$REPO_URL" 2>&1 && REPO_OK=1 || {
            echo "  Clone failed. Set GITHUB_TOKEN in your config or check repo name."
            echo "  You can clone manually after connecting via SSH."
        }
    fi
fi

# Setup opencode (only if repo cloned successfully)
if [ "$REPO_OK" -eq 1 ]; then
    cd "/workspace/$PROJECT"
    chown -R phonecoder:phonecoder /workspace/"$PROJECT"
    HAS_REPO=1

    # Create session branch
    git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME" 2>/dev/null || true

    # Fetch opencode API key from Secrets Manager
    if [ -n "$OPENCODE_SECRET_ARN" ]; then
        echo "Fetching opencode API key..."
        aws secretsmanager get-secret-value --secret-id "$OPENCODE_SECRET_ARN" --query SecretString --output text > /tmp/opencode-secrets.json 2>/dev/null || true

        DEEPSEEK_KEY=$(jq -r '.DEEPSEEK_API_KEY // empty' /tmp/opencode-secrets.json 2>/dev/null || echo '')

        if [ -n "$DEEPSEEK_KEY" ]; then
            export DEEPSEEK_API_KEY="${DEEPSEEK_KEY}"
            su - phonecoder -c "mkdir -p ~/.local/share/opencode && cat > ~/.local/share/opencode/auth.json" << AUTHJSON
{
    "deepseek": {
        "type": "api",
        "key": "${DEEPSEEK_KEY}"
    }
}
AUTHJSON
            chown phonecoder:phonecoder /home/phonecoder/.local/share/opencode/auth.json
            chmod 600 /home/phonecoder/.local/share/opencode/auth.json
        fi
        rm -f /tmp/opencode-secrets.json
    fi

    # Set up opencode profile for phonecoder
    su - phonecoder -c "
        mkdir -p ~/.opencode
        cat > ~/.opencode/config.json << 'EOFCFG'
{
    \"provider\": {
        \"deepseek\": {
            \"npm\": \"@ai-sdk/openai-compatible\",
            \"name\": \"DeepSeek\",
            \"options\": {
                \"baseURL\": \"https://api.deepseek.com/v1\"
            },
            \"models\": {
                \"deepseek-v4-pro\": {
                    \"name\": \"DeepSeek-V4-Pro\",
                    \"tools\": true
                },
                \"deepseek-chat\": {
                    \"name\": \"DeepSeek-V3.2\",
                    \"tools\": true
                },
                \"deepseek-reasoner\": {
                    \"name\": \"DeepSeek-R1\",
                    \"tools\": true
                }
            }
        }
    },
    \"model\": \"deepseek/deepseek-v4-pro\"
}
EOFCFG
    "

    # Launch auto-push in background
    cat > /home/phonecoder/auto-push.sh << 'PUSHSCRIPT'
#!/bin/bash
PUSH_INTERVAL="${PUSH_INTERVAL:-300}"
while true; do
    sleep "$PUSH_INTERVAL"
    if git rev-parse --git-dir > /dev/null 2>&1; then
        if ! git diff --quiet || ! git diff --cached --quiet; then
            git add -A
            git commit -m "Auto-save: $(date)" || true
        fi
        CURRENT_BRANCH=$(git branch --show-current)
        if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
            git push origin "$CURRENT_BRANCH" 2>/dev/null || git push -u origin "$CURRENT_BRANCH" 2>/dev/null
        fi
    fi
done
PUSHSCRIPT
    chmod +x /home/phonecoder/auto-push.sh
    su - phonecoder -c "cd /workspace/$PROJECT && /home/phonecoder/auto-push.sh &"
fi

# Write motd with session info
if [ "$REPO_OK" -eq 1 ]; then
    cat > /etc/motd << MOTD
=== Phone Code Session ===
Project: $PROJECT
Branch:  $BRANCH_NAME
Repo:    /workspace/$PROJECT

Type 'opencode' to start coding.
Auto-push is running every 5 minutes.
MOTD
else
    cat > /etc/motd << MOTD
=== Phone Code Session ===
Project: $PROJECT

WARNING: Could not clone $PROJECT.
Check that the repo exists and your token has access.
The container is still running — you can clone manually.

Workspace: /workspace
MOTD
fi

# Create .bashrc that auto-launches opencode on login (if repo ok)
echo "$PROJECT" > /home/phonecoder/.phone-project

# .bash_profile ensures .bashrc runs for SSH login shells
cat > /home/phonecoder/.bash_profile << 'PROFILE'
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
PROFILE

cat > /home/phonecoder/.bashrc << 'BASHRC'
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi
cat /etc/motd
PROJECT=$(cat /home/phonecoder/.phone-project 2>/dev/null || echo '')
if [ -n "$PROJECT" ] && [ -d "/workspace/$PROJECT" ]; then
    cd "/workspace/$PROJECT"
    opencode
else
    cd /workspace
    echo ""
    echo "No project cloned. Clone one manually:"
    echo "  git clone https://github.com/your-org/your-repo.git"
fi
BASHRC
chown phonecoder:phonecoder /home/phonecoder/.bashrc /home/phonecoder/.phone-project

echo "Container ready. Waiting for SSH connections..."

# Keep container alive
tail -f /var/log/auth.log 2>/dev/null || sleep infinity
