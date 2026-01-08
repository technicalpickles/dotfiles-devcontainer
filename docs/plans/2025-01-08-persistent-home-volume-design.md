# Persistent Home Volume for Devcontainers

## Problem

Container rebuilds destroy user state: shell history, Claude sessions, tool caches, and application configs. Developers must reconfigure their environment after each rebuild.

## Solution

Mount a persistent Docker volume at `/home/vscode`. The volume survives container rebuilds, preserving all user state. Dotfiles setup moves from image build time to container start time.

## Design

### Volume Configuration

The home volume uses devcontainer's native volume support:

```json
"mounts": [
  {
    "source": "${devcontainerId}-home",
    "target": "/home/vscode",
    "type": "volume"
  }
]
```

**Naming:** `${devcontainerId}-home` provides automatic per-project uniqueness. The `devcontainerId` variable is stable across rebuilds but unique per devcontainer definition.

**Behavior:** Always enabled, no opt-out. This is the standard behavior for all devcontainers created from this template.

### Template Changes

**`devcontainer.json`:**

- Add home volume mount to `mounts` array
- Move `DOTFILES_REPO` and `DOTFILES_BRANCH` from build args to `containerEnv`
- Remove `DOCKER_BUILD` build arg (no longer needed)

**`Dockerfile`:**

- Remove `setup-dotfiles` call
- Keep shell configuration (`chsh`) for now (deferred to future shell feature)

**`post-create.sh`:**

- Call `setup-dotfiles` using environment variables
- Continue calling `devcontainer-post-create` for remaining setup

### Lifecycle

**First container start (empty volume):**

1. Docker creates empty volume
2. Volume mounted at `/home/vscode`
3. `post-create.sh` runs `setup-dotfiles`
4. Dotfiles cloned and installed
5. Home directory populated

**Subsequent rebuilds:**

1. Existing volume mounted at `/home/vscode`
2. `post-create.sh` runs `setup-dotfiles`
3. Dotfiles synced/updated (idempotent)
4. Existing history, sessions, caches preserved

### What Persists

Everything in `/home/vscode`:

- `~/.local/share/fish/fish_history` - shell history
- `~/.claude/` - Claude sessions
- `~/.cache/` - tool caches
- `~/.config/` - application configs
- `~/.dotfiles/` - cloned dotfiles repo

### Recovery

If `setup-dotfiles` fails or home becomes corrupted:

1. Remove the volume: `docker volume rm <devcontainerId>-home`
2. Rebuild the container
3. Fresh volume created and populated

Users can also re-run `setup-dotfiles` manually inside the container.

## File Changes

### `src/dotfiles/.devcontainer/devcontainer.json`

```json
{
  "name": "Dotfiles Dev Environment",
  "build": {
    "dockerfile": "Dockerfile",
    "args": {
      "USER_SHELL": "${templateOption:userShell}"
    }
  },
  "mounts": [
    {
      "source": "${devcontainerId}-home",
      "target": "/home/vscode",
      "type": "volume"
    }
  ],
  "containerEnv": {
    "DOTFILES_REPO": "${templateOption:dotfilesRepo}",
    "DOTFILES_BRANCH": "${templateOption:dotfilesBranch}",
    "${templateOption:installEnvVars}": ""
  },
  "remoteEnv": {
    "GITHUB_TOKEN": "${localEnv:GITHUB_TOKEN}"
  },
  "features": {
    "ghcr.io/technicalpickles/devcontainer-features/dind:0.1.1": {},
    "ghcr.io/technicalpickles/devcontainer-features/aws-cli:0.1.0": {}
  },
  "postCreateCommand": "bash .devcontainer/post-create.sh",
  "initializeCommand": "mkdir -p ${localEnv:HOME}/.aws",
  "customizations": {
    "vscode": {
      "extensions": ["esbenp.prettier-vscode"],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "${templateOption:userShellName}",
        "terminal.integrated.profiles.linux": {
          "${templateOption:userShellName}": {
            "path": "${templateOption:userShell}"
          }
        }
      }
    }
  }
}
```

### `src/dotfiles/.devcontainer/Dockerfile`

```dockerfile
FROM ghcr.io/technicalpickles/dotfiles-devcontainer/base:latest

ARG USER_SHELL=${templateOption:userShell}

USER root
RUN chsh -s "${USER_SHELL}" vscode
USER vscode
```

### `src/dotfiles/.devcontainer/post-create.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Setup dotfiles in the persistent home volume
setup-dotfiles --repo "${DOTFILES_REPO}" --branch "${DOTFILES_BRANCH}"

# Run base image's post-create (git safe.directory, project hooks, etc.)
devcontainer-post-create
```

## Future Work

- **Shell configuration feature:** Extract `chsh` and VS Code terminal config into a composable devcontainer feature (see GitHub issue)
