# docker/base/ - Base Image

Multi-architecture base image published to GHCR.

## References

@docs/ci.md
@docs/plans/2025-11-27-base-image-plan.md
@specs/001-multi-arch-base/spec.md

## Building Locally

```bash
./bin/build-base    # Build for current architecture
./bin/test-base     # Run Goss validation
```

## Dockerfile Contents

Ubuntu-based image with pre-installed tools:

- Fish shell, Starship prompt
- gh CLI, mise, tmux
- AWS CLI v2, 1Password CLI
- Docker engine components (for DinD feature)
- Goss (for smoke testing)

## Key Files

- `Dockerfile` - Multi-arch base image definition
- `setup-dotfiles` - Helper script for dotfiles installation
- `devcontainer-post-create` - Base entrypoint (installed to `/usr/local/bin/`)

## Goss Validation

`docker/goss.yaml` defines smoke tests run on each architecture after build.

## Multi-Architecture

CI builds both `linux/amd64` and `linux/arm64` using Docker Buildx with QEMU.

- Candidate tag pushed first
- Each architecture tested with Goss
- Promoted to release tags after validation

## Constraints

- Keep vscode UID/GID for permission compatibility
- Docker engine bits must be baked in (DinD feature only wires startup)
- Build secrets for sensitive tokens (never layer-persisted)
