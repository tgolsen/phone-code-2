#!/bin/bash
# Auto-push script for safety - runs on remote instance
# Usage: ./auto-push.sh &

PUSH_INTERVAL="${PUSH_INTERVAL:-300}" # 5 minutes default

echo "🔄 Auto-push started (every ${PUSH_INTERVAL}s)"

while true; do
    sleep "$PUSH_INTERVAL"

    # Check if we're in a git repo
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Check if there are any changes
        if ! git diff --quiet || ! git diff --cached --quiet; then
            echo "💾 Auto-saving changes..."
            git add .
            git commit -m "Auto-save: $(date)" || true
        fi

        # Push current branch
        CURRENT_BRANCH=$(git branch --show-current)
        if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
            echo "⬆️  Auto-pushing branch: $CURRENT_BRANCH"
            git push origin "$CURRENT_BRANCH" 2>/dev/null || {
                echo "⚠️  Push failed, setting upstream..."
                git push -u origin "$CURRENT_BRANCH" 2>/dev/null || echo "❌ Auto-push failed"
            }
        fi
    fi
done