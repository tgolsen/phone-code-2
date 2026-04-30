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

# Start sshd
/usr/sbin/sshd
echo "SSHD running on port 2222"

# Clone or pull repo
cd /workspace
if [ -d "$PROJECT" ]; then
    echo "Pulling existing repo..."
    git -C "$PROJECT" fetch origin
    git -C "$PROJECT" checkout main 2>/dev/null || git -C "$PROJECT" checkout master 2>/dev/null
    git -C "$PROJECT" pull
else
    echo "Cloning repo..."
    if [ -n "$GITHUB_TOKEN" ]; then
        git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${PROJECT}.git"
    else
        git clone "$REPO_URL"
    fi
fi

# Create session branch
cd "/workspace/$PROJECT"
git checkout -b "$BRANCH_NAME"

# Fetch opencode API key from Secrets Manager if configured
if [ -n "$OPENCODE_SECRET_ARN" ]; then
    echo "Fetching opencode API key..."
    aws secretsmanager get-secret-value --secret-id "$OPENCODE_SECRET_ARN" --query SecretString --output text > /tmp/opencode-secrets.json

    # Extract values
    DEEPSEEK_KEY=$(jq -r '.DEEPSEEK_API_KEY // empty' /tmp/opencode-secrets.json)
    export DEEPSEEK_API_KEY="${DEEPSEEK_KEY}"

    # Write opencode auth.json for the phonecoder user
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

    rm /tmp/opencode-secrets.json
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
    \"model\": \"deepseek/deepseek-chat\"
}
EOFCFG
"

# Write auto-push script for safety
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

# Launch auto-push in background as phonecoder
su - phonecoder -c "cd /workspace/$PROJECT && /home/phonecoder/auto-push.sh &"

# Write motd with session info
cat > /etc/motd << MOTD
=== Phone Code Session ===
Project: $PROJECT
Branch:  $BRANCH_NAME
Repo:    /workspace/$PROJECT

Type 'opencode' to start coding.
Auto-push is running every 5 minutes.
MOTD

# Create .bashrc that auto-launches opencode on login
cat > /home/phonecoder/.bashrc << 'BASHRC'
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi
cat /etc/motd
cd "/workspace/$PROJECT"
opencode
BASHRC
chown phonecoder:phonecoder /home/phonecoder/.bashrc

echo "Container ready. Waiting for SSH connections..."

# Keep container alive
tail -f /var/log/auth.log 2>/dev/null || sleep infinity
