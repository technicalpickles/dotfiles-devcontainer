# features/ - Devcontainer Features

Source for published devcontainer features.

## References

@docs/features.md
@specs/003-publish-dind-feature/spec.md
@docs/plans/2025-11-10-aws-sso-credentials-design.md
@docs/plans/2025-12-11-github-token-auth-design.md

## Current Features

### dind (Docker-in-Docker)

- Registry: `ghcr.io/technicalpickles/devcontainer-features/dind`
- Wires Docker-in-Docker using bits baked into base image
- Requires privileged mode

### aws-cli (AWS CLI Credentials Mount)

- Registry: `ghcr.io/technicalpickles/devcontainer-features/aws-cli`
- Mounts host `~/.aws` read-only

### claude-code (Claude Code CLI)

- Registry: `ghcr.io/technicalpickles/devcontainer-features/claude-code`
- Installs Claude Code CLI via official installer
- User authenticates interactively on first use

## Feature Structure

Each feature has:

```text
features/{name}/
├── devcontainer-feature.json  # Metadata, mounts, env, entrypoints
└── install.sh                 # Info script (actual setup via metadata)
```

## Publishing

```bash
# Publish a feature
bin/publish-feature <name>

# Dry run
bin/publish-feature <name> --dry-run

# Skip tests
bin/publish-feature <name> --skip-tests
```

## Adding a New Feature

1. Create `features/{name}/` with `devcontainer-feature.json` and `install.sh`
2. Add tests: `test/features/{name}/test.sh`
3. Publish: `./bin/publish-feature {name}`
4. Update `docs/features.md` with version and digest
5. Reference in `devcontainer.json` features block

## Development Mode

Use `bin/apply local-dev <target>` to work with vendored features before publishing.
