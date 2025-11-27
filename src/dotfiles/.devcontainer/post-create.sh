#!/usr/bin/env bash
set -euo pipefail
set -x

echo "Running post-create setup..."

DOTFILES_DIR="/home/vscode/.dotfiles"
# shellcheck disable=SC2154 # templateOption placeholders replaced by apply
DEFAULT_REPO="${templateOption:dotfilesRepo}"
DEFAULT_BRANCH="${templateOption:dotfilesBranch}"
REPO_URL=$(git -C "${DOTFILES_DIR}" config --get remote.origin.url || echo "${DEFAULT_REPO}")
BRANCH_NAME=$(git -C "${DOTFILES_DIR}" rev-parse --abbrev-ref HEAD || echo "${DEFAULT_BRANCH}")

echo "📦 Syncing dotfiles (${REPO_URL}@${BRANCH_NAME})..."
setup-dotfiles --repo "${REPO_URL}" --branch "${BRANCH_NAME}"
echo "✓ Dotfiles sync complete"
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
