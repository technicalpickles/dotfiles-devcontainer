# GitHub Token Authentication Design

**Date:** 2025-12-11
**Status:** Design
**Owner:** technicalpickles

## Goals

Ensure GitHub API requests are always authenticated across all stages (build, post-create, runtime) to avoid rate limiting, without persisting tokens in images or container definitions.

## Core Requirements

1. GITHUB_TOKEN available at **build time** (base image, features)
2. GITHUB_TOKEN available at **post-create time** (dotfiles setup, mise installs)
3. GITHUB_TOKEN available at **runtime** (developer shell sessions)
4. Token is **NEVER baked into any image or container definition**

## Design Overview

The token is sourced fresh from the host environment at each stage and injected temporarily:

- **Build:** Passed as Docker build secret (never persisted in layers)
- **Post-create + Runtime:** Forwarded from host via `remoteEnv` (re-sourced on container start)

## Token Sourcing Strategy

### Priority Order

Create `bin/lib/resolve-github-token.sh` that resolves tokens with this priority:

1. `$GITHUB_TOKEN` if already set in environment
2. `fnox get GITHUB_TOKEN` if fnox is available
3. `gh auth token` as fallback
4. Error with helpful message if none available

### Implementation

```bash
#!/usr/bin/env bash
resolve_github_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "Using GITHUB_TOKEN from environment" >&2
    echo "$GITHUB_TOKEN"
    return 0
  fi

  if command -v fnox >/dev/null 2>&1; then
    if token=$(fnox get GITHUB_TOKEN 2>/dev/null) && [[ -n "$token" ]]; then
      echo "Resolved GITHUB_TOKEN via fnox" >&2
      echo "$token"
      return 0
    fi
  fi

  if command -v gh >/dev/null 2>&1; then
    if token=$(gh auth token 2>/dev/null) && [[ -n "$token" ]]; then
      echo "Resolved GITHUB_TOKEN via gh CLI" >&2
      echo "$token"
      return 0
    fi
  fi

  echo "Error: GITHUB_TOKEN not available. Try: gh auth login, fnox, or export GITHUB_TOKEN=..." >&2
  return 1
}
```

## Build-Time Integration

### Base Image Dockerfile Changes

Modify `docker/base/Dockerfile` to accept and use the build secret:

```dockerfile
# Install mise and starship
RUN --mount=type=secret,id=github_token \
    export GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || echo "") \
    && curl https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise \
    && curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir /usr/local/bin
```

**Key points:**

- `--mount=type=secret,id=github_token` makes secret available at `/run/secrets/github_token`
- Secret only exists during RUN execution - never persisted in layers
- Graceful fallback if secret is empty (allows builds without token, may hit rate limits)

### Local Build Script Updates

Update `bin/build-base`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the token resolution library
source "$SCRIPT_DIR/lib/resolve-github-token.sh"

IMAGE_TAG="${IMAGE_TAG:-ghcr.io/technicalpickles/dotfiles-devcontainer/base:latest}"

# Resolve token
if ! GITHUB_TOKEN=$(resolve_github_token); then
  echo "Warning: Building without GitHub authentication - may hit rate limits"
  GITHUB_TOKEN=""
fi

echo "Building base image: ${IMAGE_TAG}"
DOCKER_BUILDKIT=1 docker build \
  --pull \
  --secret id=github_token,env=GITHUB_TOKEN \
  -f "${REPO_ROOT}/docker/base/Dockerfile" \
  -t "${IMAGE_TAG}" \
  "${REPO_ROOT}"

echo "✓ Build complete: ${IMAGE_TAG}"
```

### GitHub Actions Changes

Update `.github/workflows/base-image-publish.yaml` to pass the secret:

```yaml
- name: Build and push multi-arch candidate image
  uses: docker/build-push-action@v5
  with:
    context: .
    file: docker/base/Dockerfile
    pull: true
    push: true
    platforms: ${{ env.PLATFORMS }}
    tags: ${{ env.CANDIDATE_TAG }}
    labels: ${{ steps.meta.outputs.labels }}
    cache-from: type=gha,scope=base-image
    cache-to: type=gha,scope=base-image,mode=max
    secrets: |
      github_token=${{ secrets.GITHUB_TOKEN }}
```

## Post-Create Integration

### devcontainer.json Changes

Add `remoteEnv` to forward token from host (add to `src/dotfiles/.devcontainer/devcontainer.json`):

```json
{
  "name": "Dotfiles Dev Environment",
  "build": { ... },
  "remoteEnv": {
    "GITHUB_TOKEN": "${localEnv:GITHUB_TOKEN}"
  },
  "containerEnv": "${templateOption:installEnvVars}",
  ...
}
```

**Behavior:**

- `${localEnv:GITHUB_TOKEN}` reads from host environment at container start
- If not present on host → empty/unset in container (graceful degradation)
- Available to post-create scripts and runtime shells

### Post-Create Scripts

**No changes needed!** Scripts like `devcontainer-post-create` and `setup-dotfiles` will automatically use `$GITHUB_TOKEN` if present. Tools respect it natively:

- `git clone` uses it for authentication
- `mise install` uses it for GitHub API calls
- `gh` commands use it for API authentication

## Runtime Integration

### Environment Forwarding

The same `remoteEnv` configuration makes GITHUB_TOKEN available at runtime automatically.

### Developer Experience

Developers have multiple options to set up their host environment:

```bash
# Option 1: Export directly
export GITHUB_TOKEN=ghp_...

# Option 2: Use fnox (token automatically resolved)
fnox set GITHUB_TOKEN ghp_...

# Option 3: Use gh CLI (token automatically resolved)
gh auth login

# Option 4: Do nothing (works but may hit rate limits)
```

Inside the container, all GitHub API calls are authenticated if token was available on host.

### Benefits

- No in-container authentication needed
- Token sourced fresh on each container start
- Works offline if host has token
- Transparent to existing scripts and tools

## Security Properties

1. **Never persisted in images:** Build secrets disappear after RUN completes
2. **Never in container config:** Token forwarded at runtime, not baked into devcontainer.json
3. **Never in version control:** Token comes from host environment/secrets
4. **Scoped per-developer:** Each developer uses their own token from their own host
5. **Auditable:** GitHub tracks API usage by token

## Testing Strategy

### Local Testing

1. Build base image: `bin/build-base`
   - Verify token resolution works (fnox → gh fallback)
   - Verify mise installation succeeds without rate limiting
2. Test devcontainer template: `bin/apply` then open in VS Code
   - Verify GITHUB_TOKEN forwarded to container
   - Verify post-create scripts run without rate limiting
   - Verify runtime commands like `gh api rate_limit` show authenticated limit (5000)

### CI Testing

GitHub Actions already provides `secrets.GITHUB_TOKEN` automatically - workflows should pass without changes once secrets are added to build steps.

## Rollout Plan

1. Create `bin/lib/resolve-github-token.sh` helper script
2. Update `docker/base/Dockerfile` with build secret mount
3. Update `bin/build-base` to resolve and inject token
4. Update `.github/workflows/base-image-publish.yaml` with secrets
5. Update `src/dotfiles/.devcontainer/devcontainer.json` with remoteEnv
6. Update template to include remoteEnv in generated configs
7. Test locally and in CI
8. Document in README for developers

## Open Considerations

- Should we add a health check script that verifies GITHUB_TOKEN is available and shows current rate limit status?
- Should we add a pre-build hook that warns if token is missing?
- Consider adding similar patterns for other API tokens (AWS, etc.) if needed in the future
