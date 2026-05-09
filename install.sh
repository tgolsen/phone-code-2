#!/usr/bin/env bash
set -e

INSTALL_DIR="${HOME}/.phone-code"
REPO="https://raw.githubusercontent.com/tgolsen/phone-code-2/main"

echo "Phone Code installer"
echo "===================="

mkdir -p "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR"

# Download the main script
echo "Downloading phone-code..."
curl -fsSL "$REPO/phone-code" -o "$INSTALL_DIR/phone-code"
chmod +x "$INSTALL_DIR/phone-code"

# Create config from example if not exists
if [ ! -f "$HOME/.phone-code-config" ]; then
    echo "Creating config template..."
    cat > "$HOME/.phone-code-config" << 'CONFIG'
# Phone Code Configuration
# Fill in your values and uncomment each line.

# API endpoint and key (from Terraform output)
# export PHONE_CODE_API_URL="https://xxxxxxxxxx.execute-api.us-west-2.amazonaws.com"
# export PHONE_CODE_API_KEY="your-api-key"

# GitHub credentials
# export GITHUB_USER="your-github-username"
# export GITHUB_TOKEN="github_pat_..."
CONFIG
    echo ""
    echo "Config created at ~/.phone-code-config"
    echo "Edit it with your API endpoint, API key, and GitHub credentials."
else
    echo "Config already exists at ~/.phone-code-config — skipping."
fi

# Add to PATH via shell profile
SHORTCUT='export PATH="$HOME/.phone-code:$PATH"'
for profile in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile"; do
    if [ -f "$profile" ]; then
        if ! grep -qF "phone-code" "$profile" 2>/dev/null; then
            echo "" >> "$profile"
            echo "# Phone Code" >> "$profile"
            echo "$SHORTCUT" >> "$profile"
        fi
    fi
done

echo ""
echo "Done. Restart your terminal, edit ~/.phone-code-config, then:"
echo "  phone-code my-project"
