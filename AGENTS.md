# pickled-devcontainer Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-12-01

## Active Technologies

- Devcontainer base image pinned: `mcr.microsoft.com/devcontainers/base:ubuntu@sha256:8d68bbf458958747a7f41756f60de95d5b404f374f05cd42969957653fad0cfe`
- Docker-in-Docker feature enabled for template (`ghcr.io/devcontainers/features/docker-in-docker:2`)
- Helper scripts: `setup-dotfiles`, new `devcontainer-post-create` base entrypoint
- Shipped tooling: fish, starship, gh, mise, AWS CLI v2, 1Password CLI

## Devcontainer Constraints

- Base image: `ghcr.io/technicalpickles/dotfiles-devcontainer/base` (pinned digest, retains `vscode` UID/GID)
- Credential boundary: host `~/.aws` mounted read-only; no baked secrets or writeable host mounts without review
- Shell + dotfiles: user-owned values propagate across `devcontainer.json`, `Dockerfile`, post-create, and tests; avoid personal defaults

## Project Structure

```text
specs/
docker/
src/dotfiles/
bin/
test/
docs/
```

## Commands

- Template apply: `bin/apply [--repo ... --branch ...] <target_dir>`
- Template tests: `bats test/apply.bats`
- Base image smoke: `goss -g docker/goss.yaml validate`

## Code Style

Shell scripts (bash), Docker/Buildx on GitHub Actions public runners: Follow standard conventions

## Recent Changes

- 002-post-create-script: Added base `devcontainer-post-create` entrypoint and shim delegation to dotfiles/hook flow
- 001-multi-arch-base: Added Shell scripts (bash), Docker/Buildx on GitHub Actions public runners + Docker CLI/buildx, GitHub Actions workflows, bats, Goss

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
