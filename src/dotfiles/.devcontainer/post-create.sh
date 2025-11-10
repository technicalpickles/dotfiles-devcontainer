#!/usr/bin/env bash
set -euo pipefail
set -x

echo "Running post-create setup..."

# Update dotfiles to latest
echo "📦 Updating dotfiles to latest..."
cd /home/vscode/.dotfiles
git pull
echo "✓ Dotfiles updated"
echo

# Re-run dotfiles installation to pick up any updates
echo "📦 Running dotfiles installation..."
# Note: Environment variables are already set via containerEnv in devcontainer.json
bash install.sh
echo "✓ Dotfiles installation complete"
echo

# Configure git for safe directory
echo "🔧 Configuring git..."
git config --global --add safe.directory /workspaces/*
echo "✓ Git configuration complete"
echo

# Initialize git submodules if they exist and haven't been initialized
echo "🔧 Checking for git submodules..."
if [ -f .gitmodules ] && [ -d .git ]; then
  if git submodule status | grep -q '^-'; then
    echo "📦 Initializing git submodules..."
    git submodule update --init --recursive
    echo "✓ Git submodules initialized"
  else
    echo "✓ Git submodules already initialized"
  fi
else
  echo "✓ No git submodules found"
fi
echo

echo "✓ Post-create setup complete!"
echo "Ready to develop! 🚀"
