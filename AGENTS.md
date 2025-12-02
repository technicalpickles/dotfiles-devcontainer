# pickled-devcontainer Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-12-01

## Active Technologies

[EXTRACTED FROM ALL PLAN.MD FILES: include devcontainer base image pin, docker-in-docker feature usage, setup-dotfiles helper, and shipped tooling (fish, starship, gh, mise, AWS CLI, 1Password CLI)]

## Devcontainer Constraints

- Base image: `ghcr.io/technicalpickles/dotfiles-devcontainer/base` (pinned digest, retains `vscode` UID/GID)
- Credential boundary: host `~/.aws` mounted read-only; no baked secrets or writeable host mounts without review
- Shell + dotfiles: user-owned values propagate across `devcontainer.json`, `Dockerfile`, post-create, and tests; avoid personal defaults

## Project Structure

```text
src/
tests/
```

## Commands

[ONLY COMMANDS FOR ACTIVE TECHNOLOGIES; include helper scripts like `bin/apply`, `bin/build`, `bin/run`, `bin/stop`, and any test runners such as `bats test/apply.bats` or base-image smoke/Goss commands]

## Code Style

Shell scripts (bash), Docker/Buildx on GitHub Actions public runners: Follow standard conventions

## Recent Changes

- 001-multi-arch-base: Added Shell scripts (bash), Docker/Buildx on GitHub Actions public runners + Docker CLI/buildx, GitHub Actions workflows, bats, Goss

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
