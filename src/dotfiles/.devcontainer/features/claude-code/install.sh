#!/usr/bin/env bash
set -euo pipefail

echo "Installing Claude Code CLI..."

# Pre-seed minimal settings to skip interactive first-run setup.
# Without this, 'claude install' triggers the interactive configuration wizard,
# blocking container builds. Users can customize settings later via dotfiles.
CLAUDE_CONFIG_DIR="/home/vscode/.claude"
SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"
su - vscode -c "mkdir -p '$CLAUDE_CONFIG_DIR'"
if [[ ! -f $SETTINGS_FILE ]]; then
	su - vscode -c "echo '{\"hasCompletedOnboarding\": true}' > '$SETTINGS_FILE'"
	echo "Pre-seeded settings to skip interactive setup."
fi

# Use the official installer as vscode user.
# Must run as vscode so ~ expands correctly and binary installs to ~/.local/bin/
su - vscode -c 'curl -fsSL https://claude.ai/install.sh | bash'

echo "Claude Code CLI installed successfully."
echo "Note: Run 'claude' to configure authentication and preferences."
