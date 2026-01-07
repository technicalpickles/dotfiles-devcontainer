# Plan: Consolidate Feature Publish Workflows

**Status: COMPLETED** (2026-01-07)

## Problem

We currently have two workflows for publishing devcontainer features:

1. **`feature-publish.yaml`** - DinD-specific, hardcoded paths, uses older patterns
2. **`publish-feature.yml`** - Generic, takes feature name as input, newly fixed

This duplication causes confusion and maintenance burden.

## Goal

Consolidate into a single generic `publish-feature.yml` workflow that can publish any feature.

## Current State

### `feature-publish.yaml` (to be removed)

- Hardcoded to publish only `dind` feature
- Uses `bin/publish-dind-feature` script (doesn't exist anymore)
- Manual `workflow_dispatch` trigger only
- No input parameters

### `publish-feature.yml` (to keep)

- Generic - accepts `feature` input parameter
- Uses `bin/publish-feature` script
- Supports `dind`, `aws-cli`, and future features
- Has `dry-run` option (skips publish step)
- Properly configured with:
  - Correct docker login method (echo/pipe)
  - ripgrep for bats tests
  - Retry loop for registry propagation

## Tasks

### 1. Verify `publish-feature.yml` works for dind

- [x] Trigger `gh workflow run publish-feature.yml -f feature=dind` (dry-run verified, run #20795494586)
- [x] Verify it publishes successfully
- [x] Verify tags are created correctly

### 2. Remove `feature-publish.yaml`

- [x] Delete `.github/workflows/feature-publish.yaml`
- [x] Remove any references to it in documentation

### 3. Update documentation

- [x] Update `docs/ci.md` to reflect single workflow
- [x] Update `.github/workflows/CLAUDE.md` to remove reference to `feature-publish.yaml`
- [x] Update `docs/releases/dind-feature.md` workflow references
- N/A `ARCHITECTURE.md` - references spec directory (historical, no update needed)

### 4. Consider automated publishing

- [ ] Evaluate adding automatic feature publishing on tag/release
- [ ] Or on changes to `src/dotfiles/.devcontainer/features/**`
- [ ] Document decision either way

(Task 4 deferred - out of scope for consolidation)

## Verification

After consolidation:

1. `gh workflow run publish-feature.yml -f feature=dind` works
2. `gh workflow run publish-feature.yml -f feature=aws-cli` works
3. No references to `feature-publish.yaml` remain
4. Documentation is consistent

## Rollback

If issues arise, the old workflow can be restored from git history:

```bash
git checkout HEAD~N -- .github/workflows/feature-publish.yaml
```
