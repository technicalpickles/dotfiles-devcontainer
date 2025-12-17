#!/usr/bin/env bash
set -euo pipefail

echo "Installing Claude Code CLI..."

# Download and install the binary directly without running interactive setup.
# The official installer runs 'claude install' which prompts for configuration,
# blocking container builds. We skip that - users can configure on first run.

INSTALL_DIR="/home/vscode/.local/bin"
CLAUDE_DIR="/home/vscode/.local/share/claude"
GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Create directories as vscode user
su - vscode -c "mkdir -p '$INSTALL_DIR' '$CLAUDE_DIR/versions'"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
x86_64) ARCH="x64" ;;
aarch64 | arm64) ARCH="arm64" ;;
*)
	echo "Unsupported architecture: $ARCH" >&2
	exit 1
	;;
esac

PLATFORM="linux-${ARCH}"

# Get latest stable version
echo "Fetching latest Claude Code version..."
VERSION=$(curl -fsSL "${GCS_BUCKET}/stable")

if [[ -z $VERSION ]]; then
	echo "Failed to fetch version" >&2
	exit 1
fi

echo "Installing Claude Code v${VERSION}..."
BINARY_PATH="$CLAUDE_DIR/versions/$VERSION"
DOWNLOAD_URL="${GCS_BUCKET}/${VERSION}/${PLATFORM}/claude"

# Download as vscode user
su - vscode -c "curl -fsSL '$DOWNLOAD_URL' -o '$BINARY_PATH' && chmod 755 '$BINARY_PATH'"

# Create symlink
su - vscode -c "ln -sf '$BINARY_PATH' '$INSTALL_DIR/claude'"

echo "Claude Code CLI v${VERSION} installed successfully."
echo "Note: Run 'claude' to complete initial setup and authenticate."
