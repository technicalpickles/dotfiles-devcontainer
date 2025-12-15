# AWS CLI Feature Design

## Summary

Extract the AWS credentials mount from `devcontainer.json` into a standalone feature called `aws-cli`. Consolidate feature publishing infrastructure while adding this feature.

## Goals

1. Isolate AWS mount configuration into a publishable feature
2. Consolidate existing feature infrastructure (workflow, script, docs) into generic versions
3. Support all apply modes with `AWS_CLI_FEATURE_REF` pinning

## Feature Specification

**Name:** `aws-cli`
**Registry:** `ghcr.io/technicalpickles/devcontainer-features/aws-cli`

**Purpose:** Mount host `~/.aws` directory read-only for AWS CLI credential access.

**What the feature does:**

- Declares a read-only bind mount from `${localEnv:HOME}/.aws` to `/home/vscode/.aws`

**What the feature does NOT do:**

- Install AWS CLI (base image provides this)
- Run host-side commands (features cannot do this)
- Provide configuration options

### Feature Structure

```text
src/dotfiles/.devcontainer/features/aws-cli/
├── devcontainer-feature.json
├── install.sh
└── README.md
```

**devcontainer-feature.json:**

```json
{
  "id": "aws-cli",
  "version": "0.1.0",
  "name": "AWS CLI Credentials Mount",
  "description": "Mounts host ~/.aws directory for AWS CLI credential access",
  "documentationURL": "https://github.com/technicalpickles/devcontainer-features/tree/main/src/aws-cli",
  "mounts": [
    {
      "source": "${localEnv:HOME}/.aws",
      "target": "/home/vscode/.aws",
      "type": "bind"
    }
  ]
}
```

**install.sh:**

```bash
#!/bin/bash
set -e
echo "AWS CLI credentials mount configured via feature metadata."
```

## Infrastructure Consolidation

### Consolidated Publish Script

Replace `bin/publish-dind-feature` with generic `bin/publish-feature`:

```bash
bin/publish-feature <feature-name>
# e.g., bin/publish-feature dind
# e.g., bin/publish-feature aws-cli
```

The script:

1. Locates feature in `src/dotfiles/.devcontainer/features/<name>/`
2. Packages with `devcontainer features package`
3. Runs feature tests
4. Pushes to GHCR
5. Outputs digest reference

### Consolidated Workflow

Replace `.github/workflows/publish-dind-feature.yml` with `.github/workflows/publish-feature.yml`:

- **Input parameter:** `feature` name
- **On push:** Detect changed features, publish those
- **Manual dispatch:** Specify feature name

### Consolidated Documentation

Replace `docs/dind-feature.md` with `docs/features.md`:

| Feature | Version | Digest     | Status |
| ------- | ------- | ---------- | ------ |
| dind    | 0.1.1   | sha256:... | ✓      |
| aws-cli | 0.1.0   | sha256:... | ✓      |

## bin/apply Integration

### Environment Variables

Feature refs remain separate for clarity:

- `DIND_FEATURE_REF` - DinD digest pin
- `AWS_CLI_FEATURE_REF` - AWS CLI digest pin

### Mode Behavior

| Mode        | AWS_CLI_FEATURE_REF | Behavior                               |
| ----------- | ------------------- | -------------------------------------- |
| local-dev   | ignored             | Uses vendored feature                  |
| ci-unpinned | optional            | Defaults to published tag              |
| ci-pinned   | required            | Must contain `@sha256:`                |
| release     | required            | Must contain `@sha256:`, no local refs |

### Changes Required

1. Add `AWS_CLI_FEATURE_REF` validation logic
2. Add aws-cli vendored feature cleanup for non-local-dev modes
3. Add aws-cli feature ref replacement in generated devcontainer.json

### devcontainer.json Changes

**Remove** from mounts array:

```json
"source=${localEnv:HOME}/.aws,target=/home/vscode/.aws,type=bind,readonly"
```

**Add** to features:

```json
"features": {
  "ghcr.io/technicalpickles/devcontainer-features/dind:0.1.1": {},
  "ghcr.io/technicalpickles/devcontainer-features/aws-cli:0.1.0": {}
}
```

**Keep** in devcontainer.json (features cannot run host commands):

```json
"initializeCommand": "mkdir -p ${localEnv:HOME}/.aws"
```

## Testing

### Feature Tests

```text
test/features/aws-cli/
├── test.sh
└── goss.yaml
```

**goss.yaml:**

```yaml
file:
  /home/vscode/.aws:
    exists: true
    filetype: directory
```

### Integration

Smoke tests verify aws-cli feature works across all apply modes.

## Implementation Order

### Phase 1: Consolidate DinD Infrastructure

1. Create `bin/publish-feature` script
2. Create `.github/workflows/publish-feature.yml`
3. Create `docs/features.md` (migrate from `docs/dind-feature.md`)
4. Remove `bin/publish-dind-feature` and old workflow
5. Verify DinD publishes correctly

### Phase 2: Add aws-cli Feature

1. Create `src/dotfiles/.devcontainer/features/aws-cli/` structure
2. Remove mount from main `devcontainer.json`
3. Add aws-cli feature reference to features list
4. Add aws-cli entry to `docs/features.md`

### Phase 3: Update bin/apply

1. Add `AWS_CLI_FEATURE_REF` validation
2. Add aws-cli vendored feature cleanup
3. Add aws-cli feature ref replacement

### Phase 4: Testing

1. Create `test/features/aws-cli/` with goss tests
2. Update smoke tests
3. Test all apply modes

## Decisions

| Decision                   | Choice                 | Rationale                                 |
| -------------------------- | ---------------------- | ----------------------------------------- |
| Feature options            | None                   | Simple mount needs no configuration       |
| initializeCommand location | Main devcontainer.json | Features cannot run host commands         |
| Feature ref env vars       | Separate per feature   | Clearer validation, better error messages |
| Infrastructure             | Consolidated           | Reduces duplication as features grow      |
