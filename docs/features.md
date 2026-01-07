# Devcontainer Features

This document tracks all published devcontainer features for this project.

## Published Features

| Feature     | Version | Digest                                                                    | Status    |
| ----------- | ------- | ------------------------------------------------------------------------- | --------- |
| dind        | 0.1.1   | `sha256:30eeba4b20d48247dde11bbab5b813a4b3748dc34014bebec46bf28e8b658020` | Published |
| aws-cli     | 0.1.0   | _pending_                                                                 | Published |
| claude-code | 0.1.0   | `sha256:a261c312c183d6537accd61646fcb1c2c9d6d32ab9869e516385ab5431bf5d1b` | Published |

## Feature Details

### dind (Docker-in-Docker)

**Registry:** `ghcr.io/technicalpickles/devcontainer-features/dind`

**Purpose:** Configures Docker-in-Docker wiring using Docker bits baked into the base image.

**Requirements:**

- Base image must include Docker engine components
- Requires privileged container mode

**Publish:**

```bash
bin/publish-feature dind
```

### aws-cli (AWS CLI Credentials Mount)

**Registry:** `ghcr.io/technicalpickles/devcontainer-features/aws-cli`

**Purpose:** Mounts host `~/.aws` directory read-only for AWS CLI credential access.

**Requirements:**

- Host must have `~/.aws` directory (created by initializeCommand)

**Publish:**

```bash
bin/publish-feature aws-cli
```

### claude-code (Claude Code CLI)

**Registry:** `ghcr.io/technicalpickles/devcontainer-features/claude-code`

**Purpose:** Installs Claude Code CLI via the official installer. Users authenticate interactively on first use.

**Requirements:**

- None (downloads from claude.ai)

**Publish:**

```bash
bin/publish-feature claude-code
```

## Publishing Workflow

### Local Publishing

```bash
# Publish a specific feature
bin/publish-feature <feature-name>

# Dry run (no push)
bin/publish-feature <feature-name> --dry-run

# Skip tests
bin/publish-feature <feature-name> --skip-tests
```

### CI Publishing

Use the `publish-feature.yml` workflow with the feature name as input.

## Consumer Notes

- Template consumes published features by reference
- No `.devcontainer/features` folder should be present in applied repos (except in local-dev mode)
- Pin to specific versions/digests in the `features` block for reproducibility

## Local Development

Use `bin/apply local-dev <target>` to work with vendored features before publishing.
