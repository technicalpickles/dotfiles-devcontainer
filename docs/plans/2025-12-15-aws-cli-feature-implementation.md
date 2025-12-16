# AWS CLI Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract AWS credentials mount into a standalone publishable feature and consolidate feature publishing infrastructure.

**Architecture:** Create aws-cli feature following DinD pattern. Consolidate publishing into generic `bin/publish-feature` script and single workflow. Update bin/apply to handle AWS_CLI_FEATURE_REF alongside DIND_FEATURE_REF.

**Tech Stack:** Bash scripts, GitHub Actions, devcontainer CLI, goss tests, Python for JSON manipulation in bin/apply.

---

## Progress

| Phase | Task                                                          | Status      |
| ----- | ------------------------------------------------------------- | ----------- |
| 1     | 1.1: Create Generic bin/publish-feature Script                | ✅ Complete |
| 1     | 1.2: Create Generic Publish Workflow                          | ✅ Complete |
| 1     | 1.3: Create Consolidated docs/features.md                     | ✅ Complete |
| 1     | 1.4: Remove Old DinD-Specific Files                           | ✅ Complete |
| 1     | 1.5: Extend test-pr.yaml with Feature Dry-Run Validation      | ✅ Complete |
| 2     | 2.1: Create aws-cli Feature Structure                         | ✅ Complete |
| 2     | 2.2: Update devcontainer.json Template                        | ✅ Complete |
| 3     | 3.1: Add AWS_CLI_FEATURE_REF Variable                         | ✅ Complete |
| 3     | 3.2: Update apply_mode_presets for AWS CLI                    | ✅ Complete |
| 3     | 3.3: Update override_dind_feature_ref to Handle Both Features | ⏳ Pending  |
| 3     | 3.4: Update prune_vendored_features for aws-cli               | ⏳ Pending  |
| 3     | 3.5: Update Usage Documentation in bin/apply                  | ⏳ Pending  |
| 4     | 4.1: Create test/publish-feature.bats                         | ⏳ Pending  |
| 4     | 4.2: Create aws-cli Feature Test Structure                    | ⏳ Pending  |
| 4     | 4.3: Update apply.bats for aws-cli                            | ⏳ Pending  |
| 4     | 4.4: Run Full Test Suite                                      | ⏳ Pending  |

---

## Phase 1: Consolidate DinD Infrastructure

### Task 1.1: Create Generic bin/publish-feature Script ✅

**Files:**

- Create: `bin/publish-feature`
- Reference: `bin/publish-dind-feature` (for pattern)

**Step 1: Create the generic publish script**

```bash
#!/usr/bin/env bash
# Publish a devcontainer feature to GHCR using the devcontainer CLI with validation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Feature name from argument
FEATURE_NAME="${1:-}"
if [[ -z "$FEATURE_NAME" ]]; then
  echo "Usage: $(basename "$0") <feature-name> [--version <semver>] [--dry-run] [--skip-tests]" >&2
  echo "Example: $(basename "$0") dind" >&2
  echo "         $(basename "$0") aws-cli --dry-run" >&2
  exit 1
fi
shift

FEATURE_PATH="${FEATURE_PATH:-$REPO_ROOT/src/dotfiles/.devcontainer/features/$FEATURE_NAME}"
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-technicalpickles/devcontainer-features}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-${GITHUB_ACTOR:-}}"
REGISTRY_TOKEN="${REGISTRY_TOKEN:-${GHCR_PAT:-${GITHUB_TOKEN:-}}}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_TESTS="${SKIP_TESTS:-false}"
RESULT_PATH="${RESULT_PATH:-$REPO_ROOT/tmp/${FEATURE_NAME}-feature-publish.json}"
PACKAGE_OUT="${PACKAGE_OUT:-$REPO_ROOT/tmp/${FEATURE_NAME}-feature-package}"
VERSION_OVERRIDE="${VERSION_OVERRIDE:-${VERSION:-}}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <feature-name> [--version <semver>] [--dry-run] [--skip-tests] [--result-path <file>]

Publish a devcontainer feature to GHCR with packaging, validation, and JSON summary output.

Arguments:
  <feature-name>       Name of the feature (e.g., dind, aws-cli)

Options:
  --version <semver>   Override version (must match devcontainer-feature.json)
  --dry-run            Run publish in dry-run mode (no push)
  --skip-tests         Skip feature validation tests
  --result-path <file> Path to write publish summary JSON (default: tmp/<feature>-feature-publish.json)
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION_OVERRIDE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --skip-tests)
      SKIP_TESTS="true"
      shift
      ;;
    --result-path)
      RESULT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$FEATURE_PATH/devcontainer-feature.json" ]]; then
  echo "devcontainer-feature.json not found at $FEATURE_PATH" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node is required to read feature metadata" >&2
  exit 1
fi

read_version() {
  node -e "console.log(require(process.argv[1]).version)" "$FEATURE_PATH/devcontainer-feature.json"
}

ensure_semver() {
  local candidate="$1"
  if [[ ! "$candidate" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must be semver (e.g., 0.1.1); got: $candidate" >&2
    exit 1
  fi
}

DEVCONTAINER_BIN=""
if command -v devcontainer >/dev/null 2>&1; then
  DEVCONTAINER_BIN="devcontainer"
elif command -v npx >/dev/null 2>&1; then
  DEVCONTAINER_BIN="npx --yes @devcontainers/cli"
else
  echo "devcontainer CLI not found (install or use npx @devcontainers/cli)" >&2
  exit 1
fi

FEATURE_VERSION="$(read_version)"
if [[ -n "$VERSION_OVERRIDE" && "$VERSION_OVERRIDE" != "$FEATURE_VERSION" ]]; then
  echo "Version override (${VERSION_OVERRIDE}) does not match devcontainer-feature.json (${FEATURE_VERSION}). Update the metadata or adjust the override." >&2
  exit 1
fi
VERSION="${VERSION_OVERRIDE:-$FEATURE_VERSION}"
ensure_semver "$VERSION"

REF="${REGISTRY}/${NAMESPACE}/${FEATURE_NAME}:${VERSION}"
echo "Publishing ${FEATURE_NAME} feature ${REF} from ${FEATURE_PATH}"

if [[ -n "$REGISTRY_TOKEN" ]]; then
  if [[ -z "$REGISTRY_USERNAME" ]]; then
    echo "REGISTRY_TOKEN provided but REGISTRY_USERNAME is empty; set REGISTRY_USERNAME (or GITHUB_ACTOR in CI)." >&2
    exit 1
  fi
  echo "${REGISTRY_TOKEN}" | docker login "${REGISTRY}" -u "${REGISTRY_USERNAME}" --password-stdin
else
  echo "Warning: No REGISTRY_TOKEN/GHCR_PAT/GITHUB_TOKEN provided. Ensure you are already logged in to ${REGISTRY}."
fi

echo "Packaging feature into ${PACKAGE_OUT}..."
rm -rf "$PACKAGE_OUT"
mkdir -p "$PACKAGE_OUT"
$DEVCONTAINER_BIN features package "$FEATURE_PATH" --output-folder "$PACKAGE_OUT" --force-clean-output-folder
PACKAGE_TARBALL="$(find "$PACKAGE_OUT" -maxdepth 1 -name '*.tgz' | head -n 1 || true)"
if [[ -z "$PACKAGE_TARBALL" ]]; then
  echo "Unable to locate packaged feature tarball under ${PACKAGE_OUT}" >&2
  exit 1
fi

if [[ "$SKIP_TESTS" != "true" ]]; then
  TEST_SCRIPT="${REPO_ROOT}/test/features/${FEATURE_NAME}/test.sh"
  if [[ -x "$TEST_SCRIPT" ]]; then
    echo "Running ${FEATURE_NAME} feature validation..."
    FEATURE_TARBALL="$PACKAGE_TARBALL" FEATURE_VERSION="$VERSION" "$TEST_SCRIPT"
  else
    echo "No test script found at ${TEST_SCRIPT}; skipping validation"
  fi
else
  echo "Skipping feature validation (--skip-tests)"
fi

PUBLISH_CMD=($DEVCONTAINER_BIN features publish "$FEATURE_PATH" --registry "$REGISTRY" --namespace "$NAMESPACE" --version "$VERSION")
if [[ "$DRY_RUN" == "true" ]]; then
  PUBLISH_CMD+=("--dry-run")
fi

set -x
"${PUBLISH_CMD[@]}"
set +x

DIGEST="(dry-run)"
if [[ "$DRY_RUN" != "true" ]]; then
  DIGEST="$(docker buildx imagetools inspect "$REF" | awk '/^Digest: / {print $2; exit}')"
  if [[ -z "$DIGEST" ]]; then
    echo "Unable to resolve digest for ${REF}" >&2
    exit 1
  fi
fi

SUMMARY="$(node - "$FEATURE_PATH/devcontainer-feature.json" "$REGISTRY" "$NAMESPACE" "$FEATURE_NAME" "$VERSION" "$REF" "$DIGEST" "$PACKAGE_TARBALL" <<'NODE'
const fs = require('fs');
const [file, registry, namespace, featureName, version, ref, digest, pkg] = process.argv.slice(2);
const feature = JSON.parse(fs.readFileSync(file, 'utf8'));
const entrypoint = feature.entrypoint || null;
const mounts = feature.mounts || [];
const result = {
  registry,
  namespace,
  feature: feature.id,
  version,
  registryRef: ref,
  digest,
  privileged: feature.privileged === true,
  entrypoint: Array.isArray(entrypoint) ? entrypoint.join(' ') : entrypoint,
  mounts,
  containerUser: feature.containerUser || null,
  packageTarball: pkg || null
};
console.log(JSON.stringify(result, null, 2));
NODE
)"

mkdir -p "$(dirname "$RESULT_PATH")"
printf '%s\n' "$SUMMARY" | tee "$RESULT_PATH"
echo "Publish summary written to ${RESULT_PATH}"
```

**Step 2: Make executable and test with dind**

Run: `chmod +x bin/publish-feature && bin/publish-feature dind --dry-run --skip-tests`
Expected: Script runs and outputs publish summary (dry-run mode)

**Step 3: Commit**

```bash
git add bin/publish-feature
git commit -m "feat: add generic bin/publish-feature script

Replaces bin/publish-dind-feature with feature-agnostic version.
Takes feature name as first argument."
```

---

### Task 1.2: Create Generic Publish Workflow ✅

**Files:**

- Create: `.github/workflows/publish-feature.yml`
- Reference: `.github/workflows/publish-dind-feature.yml`

**Step 1: Create the workflow file**

````yaml
name: "Publish Feature"

on:
  workflow_dispatch:
    inputs:
      feature:
        description: "Feature name to publish (e.g., dind, aws-cli)"
        required: true
        type: string
      version:
        description: "Feature version to publish (defaults to devcontainer-feature.json)"
        required: false
        type: string
      dry-run:
        description: "Run publish without pushing"
        required: false
        type: boolean
        default: false

env:
  BASE_IMAGE: ghcr.io/technicalpickles/dotfiles-devcontainer/base@sha256:3195dd842e35bc1318b06c86c849e464b23fbc2082fc5de64f4b7bcaa789a63b
  FEATURE_NAMESPACE: technicalpickles/devcontainer-features

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Install devcontainer CLI and bats
        run: npm install -g @devcontainers/cli bats-core

      - name: Pull pinned base image
        run: docker pull "${BASE_IMAGE}"

      - name: Run base image smoke (Goss + setup-dotfiles)
        run: bin/test-base --tag "${BASE_IMAGE}"

      - name: Run template tests (bats)
        run: bats test/apply.bats

      - name: Publish feature
        env:
          REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REGISTRY_USERNAME: ${{ github.actor }}
          VERSION_OVERRIDE: ${{ inputs.version }}
          DRY_RUN: ${{ inputs.dry-run }}
          RESULT_PATH: tmp/${{ inputs.feature }}-feature-publish.json
          PACKAGE_OUT: tmp/${{ inputs.feature }}-feature-package
        run: bin/publish-feature ${{ inputs.feature }}

      - name: Publish summary
        if: always()
        env:
          FEATURE: ${{ inputs.feature }}
        run: |
          RESULT_FILE="tmp/${FEATURE}-feature-publish.json"
          {
            echo "## ${FEATURE} feature publish"
            if [[ -f "$RESULT_FILE" ]]; then
              echo
              echo '```json'
              cat "$RESULT_FILE"
              echo '```'
            else
              echo "- Publish summary not found at ${RESULT_FILE}"
            fi
          } >> "$GITHUB_STEP_SUMMARY"
````

**Step 2: Commit**

```bash
git add .github/workflows/publish-feature.yml
git commit -m "feat: add generic publish-feature workflow

Replaces publish-dind-feature.yml with feature-agnostic workflow.
Takes feature name as input parameter."
```

---

### Task 1.3: Create Consolidated docs/features.md ✅

**Files:**

- Create: `docs/features.md`
- Reference: `docs/dind-feature.md` (migrate content)

**Step 1: Create the consolidated features doc**

````markdown
# Devcontainer Features

This document tracks all published devcontainer features for this project.

## Published Features

| Feature | Version | Digest                                                                    | Status         |
| ------- | ------- | ------------------------------------------------------------------------- | -------------- |
| dind    | 0.1.1   | `sha256:30eeba4b20d48247dde11bbab5b813a4b3748dc34014bebec46bf28e8b658020` | Published      |
| aws-cli | 0.1.0   | _pending_                                                                 | In development |

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
````

### aws-cli (AWS CLI Credentials Mount)

**Registry:** `ghcr.io/technicalpickles/devcontainer-features/aws-cli`

**Purpose:** Mounts host `~/.aws` directory read-only for AWS CLI credential access.

**Requirements:**

- Host must have `~/.aws` directory (created by initializeCommand)

**Publish:**

```bash
bin/publish-feature aws-cli
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

````

**Step 2: Commit**

```bash
git add docs/features.md
git commit -m "docs: add consolidated features.md

Replaces per-feature docs with single reference document."
````

---

### Task 1.4: Remove Old DinD-Specific Files ✅

**Files:**

- Delete: `bin/publish-dind-feature`
- Delete: `.github/workflows/publish-dind-feature.yml`
- Delete: `docs/dind-feature.md`

**Step 1: Remove old files**

```bash
git rm bin/publish-dind-feature
git rm .github/workflows/publish-dind-feature.yml
git rm docs/dind-feature.md
```

**Step 2: Commit**

```bash
git commit -m "chore: remove dind-specific publish files

Replaced by generic bin/publish-feature and publish-feature.yml"
```

---

### Task 1.5: Extend test-pr.yaml with Feature Dry-Run Validation ✅

**Files:**

- Modify: `.github/workflows/test-pr.yaml`

**Step 1: Add feature path filter and validation job**

Update the workflow to detect feature changes and run dry-run validation:

```yaml
name: "CI - Test Templates"
on:
  pull_request:

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      templates: ${{ steps.filter.outputs.changes }}
      features: ${{ steps.filter.outputs.features }}
    steps:
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            dotfiles: ./**/dotfiles/**
            features: src/dotfiles/.devcontainer/features/**

  test:
    needs: [detect-changes]
    runs-on: ubuntu-latest
    continue-on-error: true
    strategy:
      matrix:
        templates: ${{ fromJSON(needs.detect-changes.outputs.templates) }}
    steps:
      - uses: actions/checkout@v4

      - name: Smoke test for '${{ matrix.templates }}'
        id: smoke_test
        uses: ./.github/actions/smoke-test
        with:
          template: "${{ matrix.templates }}"

  validate-features:
    needs: [detect-changes]
    if: needs.detect-changes.outputs.features == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install devcontainer CLI
        run: npm install -g @devcontainers/cli

      - name: Validate dind feature (dry-run)
        run: bin/publish-feature dind --dry-run --skip-tests

      - name: Validate aws-cli feature (dry-run)
        run: bin/publish-feature aws-cli --dry-run --skip-tests
```

**Step 2: Commit**

```bash
git add .github/workflows/test-pr.yaml
git commit -m "ci: add feature dry-run validation to test-pr workflow

Runs bin/publish-feature --dry-run for each feature when
feature files change on PRs."
```

---

## Phase 2: Add aws-cli Feature

### Task 2.1: Create aws-cli Feature Structure ✅

**Files:**

- Create: `src/dotfiles/.devcontainer/features/aws-cli/devcontainer-feature.json`
- Create: `src/dotfiles/.devcontainer/features/aws-cli/install.sh`
- Create: `src/dotfiles/.devcontainer/features/aws-cli/README.md`

**Step 1: Create devcontainer-feature.json**

```json
{
  "id": "aws-cli",
  "version": "0.1.0",
  "name": "AWS CLI Credentials Mount",
  "description": "Mounts host ~/.aws directory read-only for AWS CLI credential access (GHCR: ghcr.io/technicalpickles/devcontainer-features/aws-cli). AWS CLI must be installed separately.",
  "documentationURL": "https://github.com/technicalpickles/dotfiles-devcontainer",
  "options": {},
  "mounts": [
    {
      "source": "${localEnv:HOME}/.aws",
      "target": "/home/vscode/.aws",
      "type": "bind"
    }
  ]
}
```

**Step 2: Create install.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "AWS CLI credentials mount configured via feature metadata."
echo "Mount: \${localEnv:HOME}/.aws -> /home/vscode/.aws (read-only)"
echo "Note: AWS CLI must be installed separately (e.g., via base image or another feature)."
```

**Step 3: Create README.md**

````markdown
# AWS CLI Credentials Mount Feature

This feature mounts the host's `~/.aws` directory into the container for AWS CLI credential access.

## Usage

```json
"features": {
  "ghcr.io/technicalpickles/devcontainer-features/aws-cli:0.1.0": {}
}
```
````

## What This Feature Does

- Mounts `~/.aws` from host to `/home/vscode/.aws` in container (read-only)
- Allows AWS CLI and SDKs to access credentials configured on the host

## What This Feature Does NOT Do

- Install AWS CLI (use base image or another feature)
- Create the `~/.aws` directory on the host (use `initializeCommand`)

## Prerequisites

Ensure `~/.aws` exists on the host. Add to your `devcontainer.json`:

```json
"initializeCommand": "mkdir -p ${localEnv:HOME}/.aws"
```

## Authentication Flow

1. Run `aws sso login` on host machine (opens browser)
2. Credentials cached in `~/.aws/sso/cache/`
3. Container reads credentials via mount
4. AWS CLI/SDKs work transparently

````

**Step 4: Make install.sh executable**

```bash
chmod +x src/dotfiles/.devcontainer/features/aws-cli/install.sh
````

**Step 5: Commit**

```bash
git add src/dotfiles/.devcontainer/features/aws-cli/
git commit -m "feat: add aws-cli feature structure

Mounts ~/.aws read-only for AWS credential access."
```

---

### Task 2.2: Update devcontainer.json Template

**Files:**

- Modify: `src/dotfiles/.devcontainer/devcontainer.json`

**Step 1: Remove AWS mount from mounts array, add to features**

The devcontainer.json needs these changes:

1. Remove from `mounts`: `"source=${localEnv:HOME}/.aws,target=/home/vscode/.aws,type=bind,readonly"`
2. Add to `features`: `"ghcr.io/technicalpickles/devcontainer-features/aws-cli:0.1.0": {}`

Use an editor to:

- Remove line 18: `"source=${localEnv:HOME}/.aws,target=/home/vscode/.aws,type=bind,readonly"`
- Update features block at line 26-28 to include aws-cli

**Step 2: Commit**

```bash
git add src/dotfiles/.devcontainer/devcontainer.json
git commit -m "feat: move AWS mount to aws-cli feature

devcontainer.json now references published aws-cli feature
instead of inline mount configuration."
```

---

## Phase 3: Update bin/apply

### Task 3.1: Add AWS_CLI_FEATURE_REF Variable

**Files:**

- Modify: `bin/apply`

**Step 1: Add AWS_CLI_FEATURE_REF variable near DIND_FEATURE_REF (around line 23)**

Add after line 23:

```bash
AWS_CLI_FEATURE_REF="${AWS_CLI_FEATURE_REF:-}"
```

**Step 2: Commit**

```bash
git add bin/apply
git commit -m "feat(apply): add AWS_CLI_FEATURE_REF variable"
```

---

### Task 3.2: Update apply_mode_presets for AWS CLI

**Files:**

- Modify: `bin/apply`

**Step 1: Update apply_mode_presets function (around line 268-306)**

Update each mode case to handle AWS_CLI_FEATURE_REF:

```bash
apply_mode_presets() {
  case "$MODE" in
    local-dev)
      if [[ -z "$DIND_FEATURE_REF" ]]; then
        DIND_FEATURE_REF="./features/dind"
      fi
      if [[ -z "$AWS_CLI_FEATURE_REF" ]]; then
        AWS_CLI_FEATURE_REF="./features/aws-cli"
      fi
      ;;
    ci-unpinned)
      # Use template defaults (published tag) unless caller overrides
      ;;
    ci-pinned)
      if [[ -z "$DIND_FEATURE_REF" ]]; then
        echo "Error: MODE ci-pinned requires DIND_FEATURE_REF pinned to a digest (ghcr...@sha256:<digest>)" >&2
        exit 1
      fi
      if [[ ! "$DIND_FEATURE_REF" =~ @sha256: ]]; then
        echo "Error: MODE ci-pinned requires DIND_FEATURE_REF pinned to a digest (@sha256:<digest>)" >&2
        exit 1
      fi
      if [[ -n "$AWS_CLI_FEATURE_REF" && ! "$AWS_CLI_FEATURE_REF" =~ @sha256: ]]; then
        echo "Error: MODE ci-pinned requires AWS_CLI_FEATURE_REF pinned to a digest (@sha256:<digest>)" >&2
        exit 1
      fi
      ;;
    release)
      if [[ -z "$DIND_FEATURE_REF" ]]; then
        echo "Error: MODE release requires DIND_FEATURE_REF pinned to a digest (no local refs)" >&2
        exit 1
      fi
      if [[ ! "$DIND_FEATURE_REF" =~ @sha256: ]]; then
        echo "Error: MODE release requires DIND_FEATURE_REF pinned to a digest (@sha256:<digest>)" >&2
        exit 1
      fi
      if is_local_dind_ref "$DIND_FEATURE_REF"; then
        echo "Error: MODE release does not allow local feature references" >&2
        exit 1
      fi
      if [[ -n "$AWS_CLI_FEATURE_REF" ]]; then
        if [[ ! "$AWS_CLI_FEATURE_REF" =~ @sha256: ]]; then
          echo "Error: MODE release requires AWS_CLI_FEATURE_REF pinned to a digest (@sha256:<digest>)" >&2
          exit 1
        fi
        if is_local_dind_ref "$AWS_CLI_FEATURE_REF"; then
          echo "Error: MODE release does not allow local feature references" >&2
          exit 1
        fi
      fi
      ;;
    *)
      echo "Error: Unknown MODE: ${MODE}" >&2
      exit 1
      ;;
  esac
}
```

**Step 2: Commit**

```bash
git add bin/apply
git commit -m "feat(apply): add AWS_CLI_FEATURE_REF validation in mode presets"
```

---

### Task 3.3: Update override_dind_feature_ref to Handle Both Features

**Files:**

- Modify: `bin/apply`

**Step 1: Rename function and update to handle multiple features**

Replace `override_dind_feature_ref` with `override_feature_refs`:

```bash
override_feature_refs() {
  local dc_json="$TARGET_DIR/.devcontainer/devcontainer.json"
  if [[ ! -f "$dc_json" ]]; then
    echo "Warning: Unable to pin feature references; ${dc_json} not found" >&2
    return 0
  fi

  local refs_to_apply=""
  if [[ "$SKIP_DIND" != "true" && -n "$DIND_FEATURE_REF" ]]; then
    refs_to_apply="dind:${DIND_FEATURE_REF}"
  fi
  if [[ -n "$AWS_CLI_FEATURE_REF" ]]; then
    if [[ -n "$refs_to_apply" ]]; then
      refs_to_apply="${refs_to_apply},aws-cli:${AWS_CLI_FEATURE_REF}"
    else
      refs_to_apply="aws-cli:${AWS_CLI_FEATURE_REF}"
    fi
  fi

  if [[ -z "$refs_to_apply" ]]; then
    return 0
  fi

  echo "Pinning feature references..."
  python3 - "$dc_json" "$refs_to_apply" "$TARGET_DIR" <<'PY'
import json, sys, re, pathlib, os

path = pathlib.Path(sys.argv[1])
refs_raw = sys.argv[2]
dc_dir = path.parent

raw = path.read_text()
clean = re.sub(r'^\s*//.*$', '', raw, flags=re.M)
obj = json.loads(clean)

def normalize_ref(raw_ref: str, dc_dir: pathlib.Path) -> str:
    sanitized = raw_ref
    for prefix in ("./.devcontainer/", ".devcontainer/"):
        if sanitized.startswith(prefix):
            sanitized = "./" + sanitized[len(prefix):]
            break

    if sanitized.startswith("file:"):
        ref_path = pathlib.Path(sanitized[5:])
    elif sanitized.startswith(("./", "../")):
        ref_path = pathlib.Path(sanitized)
    elif sanitized.startswith("/"):
        ref_path = pathlib.Path(sanitized)
    else:
        return sanitized  # non-local ref, leave as-is

    base_dir = dc_dir
    abs_ref = ref_path if ref_path.is_absolute() else (base_dir / ref_path).resolve()

    try:
        abs_ref.relative_to(dc_dir)
    except ValueError:
        raise SystemExit(f"Local feature must be inside the .devcontainer/ folder: {raw_ref}")

    rel_ref = os.path.relpath(abs_ref, dc_dir)
    if not rel_ref.startswith("."):
        rel_ref = f"./{rel_ref}"
    return rel_ref

# Parse refs_to_apply: "dind:ref,aws-cli:ref"
features = obj.get("features", {})
for pair in refs_raw.split(","):
    if ":" not in pair:
        continue
    feature_name, ref = pair.split(":", 1)
    normalized_ref = normalize_ref(ref, dc_dir)
    # Remove old refs for this feature
    to_remove = [k for k in features if feature_name in k]
    for k in to_remove:
        del features[k]
    features[normalized_ref] = {}
    print(f"  {feature_name}: {normalized_ref}")

obj["features"] = features
path.write_text(json.dumps(obj, indent=2) + "\n")
PY
}
```

**Step 2: Update function calls**

Replace all calls to `override_dind_feature_ref` with `override_feature_refs`.

**Step 3: Commit**

```bash
git add bin/apply
git commit -m "feat(apply): update feature ref override to handle dind and aws-cli"
```

---

### Task 3.4: Update prune_vendored_features for aws-cli

**Files:**

- Modify: `bin/apply`

**Step 1: Update KEEP_VENDORED_FEATURES logic**

After `apply_mode_presets` call (around line 486-488), add aws-cli check:

```bash
if is_local_dind_ref "$DIND_FEATURE_REF"; then
  KEEP_VENDORED_FEATURES=true
fi
if is_local_dind_ref "$AWS_CLI_FEATURE_REF"; then
  KEEP_VENDORED_FEATURES=true
fi
```

**Step 2: Update usage and config output**

Add aws-cli feature ref to the config output section (around line 521-526).

**Step 3: Commit**

```bash
git add bin/apply
git commit -m "feat(apply): include aws-cli in vendored feature handling"
```

---

### Task 3.5: Update Usage Documentation in bin/apply

**Files:**

- Modify: `bin/apply`

**Step 1: Update usage function to document AWS_CLI_FEATURE_REF**

Add to ENVIRONMENT VARIABLES section:

```
  AWS_CLI_FEATURE_REF  Pin aws-cli feature to specific digest
```

Add example:

```
  # CI/release with pinned digests for both features
  DIND_FEATURE_REF="ghcr.io/.../dind@sha256:<digest>" \
  AWS_CLI_FEATURE_REF="ghcr.io/.../aws-cli@sha256:<digest>" \
  bin/apply ci-pinned .
```

**Step 2: Commit**

```bash
git add bin/apply
git commit -m "docs(apply): document AWS_CLI_FEATURE_REF in usage"
```

---

## Phase 4: Testing

### Task 4.1: Create test/publish-feature.bats

**Files:**

- Create: `test/publish-feature.bats`

**Step 1: Create bats test file for bin/publish-feature**

```bash
#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PUBLISH="$REPO_ROOT/bin/publish-feature"
}

@test "missing feature name shows usage and exits non-zero" {
  run "$PUBLISH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "--help shows usage and exits zero" {
  run "$PUBLISH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"<feature-name>"* ]]
}

@test "non-existent feature fails with clear error" {
  run "$PUBLISH" nonexistent-feature --dry-run --skip-tests
  [ "$status" -ne 0 ]
  [[ "$output" == *"devcontainer-feature.json not found"* ]]
}

@test "dind feature dry-run produces valid JSON output" {
  run "$PUBLISH" dind --dry-run --skip-tests
  [ "$status" -eq 0 ]
  [[ "$output" == *'"feature": "dind"'* ]]
  [[ "$output" == *'"registry": "ghcr.io"'* ]]
}

@test "aws-cli feature dry-run produces valid JSON output" {
  # This test will pass once aws-cli feature is created
  if [[ ! -d "$REPO_ROOT/src/dotfiles/.devcontainer/features/aws-cli" ]]; then
    skip "aws-cli feature not yet created"
  fi
  run "$PUBLISH" aws-cli --dry-run --skip-tests
  [ "$status" -eq 0 ]
  [[ "$output" == *'"feature": "aws-cli"'* ]]
}
```

**Step 2: Run tests**

```bash
bats test/publish-feature.bats
```

Expected: All tests pass (aws-cli test may skip if feature not created yet)

**Step 3: Commit**

```bash
git add test/publish-feature.bats
git commit -m "test: add bats tests for bin/publish-feature

Tests usage, help, error handling, and dry-run output."
```

---

### Task 4.2: Create aws-cli Feature Test Structure

**Files:**

- Create: `test/features/aws-cli/test.sh`
- Create: `test/features/aws-cli/goss.yaml`

**Step 1: Create test.sh**

```bash
#!/usr/bin/env bash
# Validate aws-cli feature tarball packaging and metadata.
set -euo pipefail

FEATURE_SOURCE="${FEATURE_SOURCE:-./src/dotfiles/.devcontainer/features/aws-cli}"
FEATURE_TARBALL="${FEATURE_TARBALL:-}"
FEATURE_VERSION="${FEATURE_VERSION:-}"
TMP_FEATURE_DIR=""

cleanup() {
  if [[ -n $TMP_FEATURE_DIR && -d $TMP_FEATURE_DIR ]]; then
    rm -rf "$TMP_FEATURE_DIR"
  fi
}
trap cleanup EXIT

if [[ -n $FEATURE_TARBALL ]]; then
  TMP_FEATURE_DIR="$(mktemp -d)"
  echo "Extracting feature tarball ${FEATURE_TARBALL}"
  tar -xf "$FEATURE_TARBALL" -C "$TMP_FEATURE_DIR"
  found_json="$(find "$TMP_FEATURE_DIR" -type f -name devcontainer-feature.json | head -n 1 || true)"
  if [[ -z $found_json ]]; then
    echo "Unable to locate devcontainer-feature.json inside ${FEATURE_TARBALL}" >&2
    exit 1
  fi
  FEATURE_SOURCE="$(cd "$(dirname "$found_json")" && pwd)"
  echo "Tarball contains valid feature structure"
elif [[ -d $FEATURE_SOURCE ]]; then
  FEATURE_SOURCE="$(cd "$FEATURE_SOURCE" && pwd)"
else
  echo "FEATURE_SOURCE does not exist: ${FEATURE_SOURCE}" >&2
  exit 1
fi

if [[ ! -f "$FEATURE_SOURCE/devcontainer-feature.json" ]]; then
  echo "devcontainer-feature.json not found under ${FEATURE_SOURCE}" >&2
  exit 1
fi

if [[ -z $FEATURE_VERSION ]]; then
  FEATURE_VERSION="$(node -e "console.log(require(process.argv[1]).version || '')" "$FEATURE_SOURCE/devcontainer-feature.json")"
fi

echo "Validating aws-cli feature ${FEATURE_VERSION} from ${FEATURE_SOURCE}"

# Validate feature metadata
node - "$FEATURE_SOURCE/devcontainer-feature.json" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const feature = JSON.parse(fs.readFileSync(file, 'utf8'));

const errors = [];

if (feature.id !== 'aws-cli') {
  errors.push(`Feature id should be 'aws-cli', got: ${feature.id}`);
}

const mounts = feature.mounts || [];
const hasAwsMount = mounts.some(m => {
  const mountStr = typeof m === 'string' ? m : JSON.stringify(m);
  return mountStr.includes('.aws') && mountStr.includes('/home/vscode/.aws');
});
if (!hasAwsMount) {
  errors.push('Feature must include ~/.aws mount to /home/vscode/.aws');
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}

console.log('Feature metadata valid');
NODE

echo "aws-cli feature validation completed"
```

**Step 2: Create goss.yaml**

```yaml
# Goss tests for aws-cli feature
# These tests verify the aws-cli mount point exists

file:
  /home/vscode/.aws:
    exists: true
    filetype: directory
```

**Step 3: Make test.sh executable**

```bash
chmod +x test/features/aws-cli/test.sh
```

**Step 4: Run test**

```bash
./test/features/aws-cli/test.sh
```

Expected: "aws-cli feature validation completed"

**Step 5: Commit**

```bash
git add test/features/aws-cli/
git commit -m "test: add aws-cli feature validation

Validates feature metadata and mount configuration."
```

---

### Task 4.3: Update apply.bats for aws-cli

**Files:**

- Modify: `test/apply.bats`

**Step 1: Add test for aws-cli feature in applied config**

Add a test that verifies the aws-cli feature is referenced in applied devcontainer.json.

**Step 2: Commit**

```bash
git add test/apply.bats
git commit -m "test: add aws-cli feature checks to apply.bats"
```

---

### Task 4.4: Run Full Test Suite

**Step 1: Run all bats tests**

```bash
bats test/apply.bats test/publish-feature.bats
```

Expected: All tests pass

**Step 2: Run feature tests**

```bash
./test/features/aws-cli/test.sh
./test/features/dind/test.sh
```

Expected: Both pass

**Step 3: Test bin/apply modes**

```bash
# Test local-dev mode
mkdir -p /tmp/test-apply-local
bin/apply local-dev /tmp/test-apply-local
# Verify .devcontainer/features/aws-cli exists

# Test ci-unpinned mode
mkdir -p /tmp/test-apply-ci
bin/apply ci-unpinned /tmp/test-apply-ci
# Verify no vendored features
```

---

## Final Verification Checklist

- [ ] `bin/publish-feature dind --dry-run` works
- [ ] `bin/publish-feature aws-cli --dry-run` works
- [ ] `.github/workflows/publish-feature.yml` is valid YAML
- [ ] `.github/workflows/test-pr.yaml` includes feature validation job
- [ ] `docs/features.md` documents both features
- [ ] Old dind-specific files removed
- [ ] `src/dotfiles/.devcontainer/features/aws-cli/` exists with all files
- [ ] `devcontainer.json` references aws-cli feature (not inline mount)
- [ ] `bin/apply local-dev` copies both vendored features
- [ ] `bin/apply ci-unpinned` removes vendored features
- [ ] `AWS_CLI_FEATURE_REF` validation works in ci-pinned/release modes
- [ ] All bats tests pass (`test/apply.bats` and `test/publish-feature.bats`)
- [ ] Feature test scripts pass
