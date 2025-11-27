# Base Image + Dotfiles Helper Plan

**Date:** 2025-11-27
**Status:** In Progress
**Owner:** technicalpickles

## Goals

- Introduce a published base image to simplify the template Dockerfile and speed pulls.
- Centralize dotfiles clone/install logic in a reusable script baked into the base image.
- Reduce layer count/size and keep the `vscode` user/UID/GID intact.
- Keep Docker-in-Docker wiring via the existing devcontainer feature; bake simpler tools (AWS CLI, 1Password CLI) into the image.
- Set up automation for frequent rebuilds and upstream base image refreshes.

## Base Image Definition

- **Image name/tag:** `ghcr.io/technicalpickles/dotfiles-devcontainer/base:latest`
- **Base:** `mcr.microsoft.com/devcontainers/base:ubuntu` (keeps `vscode` user/UID/GID).
- **Included tooling:**
  - Core packages: build-essential, git, curl, wget, ca-certificates, gnupg, lsb-release, tmux.
  - Shell/prompt: fish (via PPA), starship.
  - CLIs: GitHub CLI (apt repo), mise (install script), AWS CLI, 1Password CLI.
  - Optional: docker CLI prerequisites only (no dockerd wiring; dind stays a feature).
- **Dotfiles helper:** `/usr/local/bin/setup-dotfiles`
  - Args: `--repo <url>`, `--branch <name>`, optional `--dest` (default `/home/vscode/.dotfiles`), repeatable `--env KEY=VAL`.
  - Behavior: if dest exists, fetch/reset to branch; otherwise clone. Run `install.sh` with provided env. No `chsh`. Runs as caller.
- **Layer hygiene:** single apt RUN, `rm -rf /var/lib/apt/lists/*`, combine curl installers, avoid locale bloat.

## Template Changes

- `src/dotfiles/.devcontainer/Dockerfile`
  - `FROM ghcr.io/technicalpickles/dotfiles-devcontainer/base:latest`
  - Remove inline tool installs; call `setup-dotfiles --repo ${DOTFILES_REPO} --branch ${DOTFILES_BRANCH} --env DOCKER_BUILD=true`.
  - Keep `chsh` in the Dockerfile (likely as root) to set fish default; `setup-dotfiles` remains shell-agnostic.
- `.devcontainer/devcontainer.json`
  - Drop `aws-cli` and `op` features (now in base image).
  - Keep `docker-in-docker` feature for daemon wiring.
- `.devcontainer/post-create.sh`
  - Reuse `setup-dotfiles` to pull latest and rerun install instead of open-coded `git pull && install.sh`.

## Publishing & Freshness

- **GitHub Actions workflow:**
  - Build and push base image to GHCR on `main` pushes and on a scheduled cadence (daily/weekly).
  - Use BuildKit cache; `--pull` to pick up security updates.
  - Set GHCR labels/metadata; login via repo secrets.
- **Renovate:**
  - Pin upstream base image digest in the base Dockerfile.
  - Configure Renovate to monitor that digest and open PRs when it changes (pattern from `technicalpickles/agentic-container`).
  - Rebuild image on Renovate PRs for security refresh.

## Testing

- Update local test harness if needed to accommodate the new base image (ensuring `setup-dotfiles` is present).
- Keep existing template tests (fish/starship/mise/gh/dotfiles cloned, default shell set) passing.
- Add base-image validation:
  - **Goss**: mount a `goss.yaml` at test time to assert required packages/binaries (`fish`, `gh`, `mise`, `starship`, `aws`, `op`), `vscode` user UID/GID, and presence/executability of `/usr/local/bin/setup-dotfiles`.
  - **Functional smoke**: run a container as `vscode`, execute `setup-dotfiles --repo https://github.com/technicalpickles/dotfiles.git --branch main --env DOCKER_BUILD=true`, verify dotfiles cloned and config files present, re-run to check idempotency, and sanity-check `fish/gh/aws/op/mise/starship --version`.
  - Keep docker-in-docker out of base tests (covered by devcontainer feature).
- Local helpers:
- Add `bin/build-base` to build the base image locally. ✅
- Add `bin/test-base` to run goss + functional smoke locally, mirroring CI. ✅

## Open Considerations

- Shell selection stays in template Dockerfile (not in `setup-dotfiles`); consider future toggle for alternate shells if needed.
- docker-in-docker remains a feature to avoid reimplementing daemon wiring in the base image.
