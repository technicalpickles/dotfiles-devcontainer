#!/usr/bin/env bash
set -euo pipefail
set -x

echo "Running post-create setup..."

# Update dotfiles to latest
echo "📦 Updating dotfiles to latest..."
cd /home/vscode/.pickles
git pull
echo "✓ Dotfiles updated"
echo

# Re-run dotfiles installation to pick up any updates
echo "📦 Running dotfiles installation..."
export DOTPICKLES_ROLE="${DOTPICKLES_ROLE:-devcontainer}"
bash install.sh
echo "✓ Dotfiles installation complete"
echo

# Configure git for safe directory
echo "🔧 Configuring git..."
git config --global --add safe.directory /workspaces/*
echo "✓ Git configuration complete"
echo

echo "✓ Post-create setup complete!"
echo "Ready to develop! 🚀"
