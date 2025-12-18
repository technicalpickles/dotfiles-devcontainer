# Claude Code Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a devcontainer feature that installs Claude Code CLI via the official installer.

**Architecture:** Simple feature with install.sh that runs the official curl installer. Goss tests verify the binary exists and runs. No special metadata (mounts, entrypoints) needed.

**Tech Stack:** Bash, Goss (YAML), devcontainer features

---

## Task 1: Create Feature Directory and Metadata

Files: Create `src/dotfiles/.devcontainer/features/claude-code/devcontainer-feature.json`

### Step 1.1: Create the feature metadata file

```json
{
  "id": "claude-code",
  "version": "0.1.0",
  "name": "Claude Code CLI",
  "description": "Installs Claude Code CLI (GHCR: ghcr.io/technicalpickles/devcontainer-features/claude-code)",
  "documentationURL": "https://github.com/technicalpickles/dotfiles-devcontainer",
  "options": {}
}
```

### Step 1.2: Verify metadata file created

Run: `cat src/dotfiles/.devcontainer/features/claude-code/devcontainer-feature.json`
Expected: JSON content displayed

### Step 1.3: Commit metadata

```bash
git add src/dotfiles/.devcontainer/features/claude-code/devcontainer-feature.json
git commit -m "feat(claude-code): add feature metadata"
```

---

## Task 2: Create Install Script

Files: Create `src/dotfiles/.devcontainer/features/claude-code/install.sh`

### Step 2.1: Create the install script

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Installing Claude Code CLI..."

# Feature install scripts run as root, so we install as vscode user
# to put the binary in the correct location (~/.local/bin/claude)
su - vscode -c 'curl -fsSL https://claude.ai/install.sh | bash'

echo "Claude Code CLI installed successfully."
```

### Step 2.2: Make install script executable

Run: `chmod +x src/dotfiles/.devcontainer/features/claude-code/install.sh`

### Step 2.3: Verify install script permissions

Run: `ls -la src/dotfiles/.devcontainer/features/claude-code/install.sh`
Expected: `-rwxr-xr-x` permissions

### Step 2.4: Commit install script

```bash
git add src/dotfiles/.devcontainer/features/claude-code/install.sh
git commit -m "feat(claude-code): add install script"
```

---

## Task 3: Create Goss Test File

Files: Create `test/features/claude-code/goss.yaml`

### Step 3.1: Create the goss test file

```yaml
# Goss tests for claude-code feature
# Verifies Claude Code CLI is installed and operational

file:
  /home/vscode/.local/bin/claude:
    exists: true
    mode: "0755"
    filetype: file
    owner: vscode

command:
  claude-installed:
    exec: "command -v claude"
    exit-status: 0
  claude-version:
    exec: "claude --version"
    exit-status: 0
```

### Step 3.2: Verify goss file created

Run: `cat test/features/claude-code/goss.yaml`
Expected: YAML content displayed

### Step 3.3: Commit goss tests

```bash
git add test/features/claude-code/goss.yaml
git commit -m "test(claude-code): add goss validation tests"
```

---

## Task 4: Create Feature Test Script

Files: Create `test/features/claude-code/test.sh`

### Step 4.1: Create the test script

Following the aws-cli pattern (validates tarball packaging and metadata):

```bash
#!/usr/bin/env bash
# Validate claude-code feature tarball packaging and metadata.
set -euo pipefail

FEATURE_SOURCE="${FEATURE_SOURCE:-./src/dotfiles/.devcontainer/features/claude-code}"
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

echo "Validating claude-code feature ${FEATURE_VERSION} from ${FEATURE_SOURCE}"

# Validate feature metadata
node - "$FEATURE_SOURCE/devcontainer-feature.json" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const feature = JSON.parse(fs.readFileSync(file, 'utf8'));

const errors = [];

if (feature.id !== 'claude-code') {
  errors.push(`Feature id should be 'claude-code', got: ${feature.id}`);
}

if (!feature.version || !/^\d+\.\d+\.\d+$/.test(feature.version)) {
  errors.push(`Feature version should be semver, got: ${feature.version}`);
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}

console.log('Feature metadata valid');
NODE

echo "claude-code feature validation completed"
```

### Step 4.2: Make test script executable

Run: `chmod +x test/features/claude-code/test.sh`

### Step 4.3: Verify test script permissions

Run: `ls -la test/features/claude-code/test.sh`
Expected: `-rwxr-xr-x` permissions

### Step 4.4: Run test against source

Run: `./test/features/claude-code/test.sh`
Expected: "claude-code feature validation completed"

### Step 4.5: Commit test script

```bash
git add test/features/claude-code/test.sh
git commit -m "test(claude-code): add tarball validation test"
```

---

## Task 5: Run All Tests

### Step 5.1: Run BATS tests

Run: `./bin/test-bats`
Expected: All tests pass (existing tests unaffected)

### Step 5.2: Run feature test

Run: `./test/features/claude-code/test.sh`
Expected: "claude-code feature validation completed"

### Step 5.3: Verify clean working directory

Run: `git status`
Expected: Clean working directory (all committed)

---

## Task 6: Update Documentation

Files: Modify `src/dotfiles/.devcontainer/features/CLAUDE.md`

### Step 6.1: Add claude-code to CLAUDE.md

Add after the aws-cli section:

```markdown
### claude-code (Claude Code CLI)

- Registry: `ghcr.io/technicalpickles/devcontainer-features/claude-code`
- Installs Claude Code CLI via official installer
- User authenticates interactively on first use
```

### Step 6.2: Commit documentation

```bash
git add src/dotfiles/.devcontainer/features/CLAUDE.md
git commit -m "docs(claude-code): add feature to CLAUDE.md"
```

---

## Task 7: Final Verification

### Step 7.1: Review all commits

Run: `git log --oneline main..HEAD`
Expected: 5 commits for this feature

### Step 7.2: Run all tests one more time

Run: `./bin/test-bats && ./test/features/claude-code/test.sh`
Expected: All pass

---

## Post-Implementation Notes

After merging, to publish the feature:

```bash
./bin/publish-feature claude-code
```

Then update `docs/features.md` with the version and digest.
