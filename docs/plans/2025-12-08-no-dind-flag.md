# Plan: Add --no-dind Flag to bin/apply

**Date**: 2025-12-08
**Status**: Planning
**Author**: Josh Nichols

## Problem Statement

Currently, `bin/apply` always includes Docker-in-Docker (DinD) feature in the generated devcontainer configuration. Users who don't need DinD have no way to exclude it. A `--no-dind` flag would allow users to skip DinD setup entirely.

## Solution Overview

Add a `--no-dind` flag that:

1. Skips all DinD feature reference logic
2. Removes the `"features"` section from generated `devcontainer.json`
3. Works with all existing MODE options

## Changes Required

### 1. bin/apply Script

**Add flag variable** (near line 20):

```bash
SKIP_DIND=false
```

**Add argument parsing** (in while loop around line 372):

```bash
--no-dind)
  SKIP_DIND="true"
  shift
  ;;
```

**Skip DinD processing** (before line 467):

```bash
if [[ "$SKIP_DIND" == "true" ]]; then
  DIND_FEATURE_REF=""
fi
```

**Modify override_dind_feature_ref()** (line 195):

- Add early return if `SKIP_DIND=true`

**Modify prune_vendored_features()** (line 181):

- Add early return if `SKIP_DIND=true`

**Update devcontainer.json processing** (Python scripts at lines 604 and 730):

- Remove entire `"features"` block if `SKIP_DIND=true`
- Use new parameter to pass this flag to Python

### 2. Help Text Updates

Add to usage section (around line 319):

```text
--no-dind          Skip Docker-in-Docker feature (exclude from devcontainer config)
```

Add example around line 348:

```bash
# Apply without DinD
./bin/apply ci-unpinned --no-dind /path/to/project
```

## Implementation Order

1. Add `SKIP_DIND` variable and argument parsing
2. Update `override_dind_feature_ref()` to skip when flag is set
3. Update `prune_vendored_features()` to skip when flag is set
4. Update Python JSON processing to remove `"features"` block
5. Update help text with flag and example
6. Test with manual smoke test

## Testing Approach

- Apply with `--no-dind` and verify no features section in `.devcontainer/devcontainer.json`
- Apply without flag and verify features section still present
- Test with different MODE options (local-dev, ci-unpinned, ci-pinned)
- Verify existing behavior unchanged when flag not used

## Notes

- The flag should be compatible with all MODE options
- If user specifies both `--no-dind` and `DIND_FEATURE_REF`, the flag takes precedence
- No changes needed to template source files
- No changes needed to mode presets logic (it can set DIND_FEATURE_REF, but it will be ignored/cleared)
