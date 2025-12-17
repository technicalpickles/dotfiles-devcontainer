#!/usr/bin/env bash
set -euo pipefail

echo "Installing Claude Code CLI..."

# Feature install scripts run as root, so we install as vscode user
# to put the binary in the correct location (~/.local/bin/claude)
su - vscode -c 'curl -fsSL https://claude.ai/install.sh | bash'

echo "Claude Code CLI installed successfully."
