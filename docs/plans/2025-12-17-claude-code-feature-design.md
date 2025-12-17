# Claude Code Devcontainer Feature Design

**Date:** 2025-12-17
**Status:** Approved

## Overview

Add a devcontainer feature that installs Claude Code CLI. The feature runs the official installer at container creation time, keeping the installation lightweight and simple.

## Design Decisions

### Why a Feature (Not Base Image)

Claude Code installation is lightweight:

- Single binary download (~20-100MB)
- No system dependencies or apt packages
- No kernel-level components or services
- Installs to user home directory (`~/.local/bin/`)

This contrasts with Docker, which requires apt repos, kernel components, and system services—justifying its inclusion in the base image.

### Version Handling

Always install latest version. No version pinning option.

Rationale:

- Claude Code auto-updates itself
- Simplest implementation
- Users get current version at container creation

### Authentication

Interactive authentication on first use. No credential mounting or environment wiring.

Rationale:

- Simplest implementation
- Claude's OAuth flow works fine interactively
- Avoids complexity of syncing auth state between host/container
- Future iteration can add Bedrock/API key support if needed

## Feature Structure

```text
src/dotfiles/.devcontainer/features/claude-code/
├── devcontainer-feature.json
└── install.sh
```

### devcontainer-feature.json

```json
{
  "id": "claude-code",
  "version": "0.1.0",
  "name": "Claude Code CLI",
  "description": "Installs Claude Code CLI (GHCR: ghcr.io/technicalpickles/devcontainer-features/claude-code)",
  "documentationURL": "https://github.com/technicalpickles/dotfiles-devcontainer",
  "options": {}
}
```

### install.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

# Install Claude Code CLI for the vscode user
su - vscode -c 'curl -fsSL https://claude.ai/install.sh | bash'
```

Feature install scripts run as root, so `su - vscode` ensures installation goes to the correct user's `~/.local/bin/`.

## Testing

### Goss Tests (Runtime Validation)

`test/features/claude-code/goss.yaml`:

```yaml
# Goss tests for claude-code feature
# Verifies Claude Code CLI is installed and operational

file:
  /home/vscode/.local/bin/claude:
    exists: true
    mode: "0755"
    filetype: file
    owner: vscode

command:
  claude-installed:
    exec: "command -v claude"
    exit-status: 0
  claude-version:
    exec: "claude --version"
    exit-status: 0
```

### test.sh (Tarball Validation)

`test/features/claude-code/test.sh` validates feature tarball packaging, following the pattern of existing features.

## Publishing

```bash
./bin/publish-feature claude-code
```

Publishes to `ghcr.io/technicalpickles/devcontainer-features/claude-code`.

## Usage

```json
{
  "features": {
    "ghcr.io/technicalpickles/devcontainer-features/claude-code:0.1.0": {}
  }
}
```

## Future Iterations

Potential enhancements (not in initial scope):

- Version pinning option
- Mount `~/.claude` from host for pre-authenticated sessions
- `ANTHROPIC_API_KEY` environment variable support via `remoteEnv`
- Bedrock/other provider configuration
