# bin/ Scripts

Helper scripts for template application, testing, and feature publishing.

## References

@docs/devcontainer-cli.md
@docs/plans/2025-11-10-dotfiles-auto-detection-design.md

## Key Scripts

### bin/apply (27KB, complex)

Main template application script. Handles:

- Dotfiles repo auto-detection (env var → git config → local dirs → gh CLI)
- Git URL normalization (SSH → HTTPS)
- Feature ref validation by MODE
- Template variable substitution

**Always test changes with:** `bats test/apply.bats`

### bin/publish-feature

Generic feature publishing to GHCR. Usage:

```bash
bin/publish-feature <name> [--dry-run] [--skip-tests] [--version X.Y.Z]
```

### bin/smoke-test

Runs full CI smoke test locally (build + test + cleanup).

- Uses `devcontainer up` which blocks on first start
- `--keep-artifacts` for debugging
- `--base-image <tag>` to test base image changes

### bin/setup-test

Sets up test environment from template with default options.

## Shared Library

`bin/lib/` contains shared functions used across scripts.

## Shell Conventions

All scripts use `set -euo pipefail` and handle cross-platform sed differences.
