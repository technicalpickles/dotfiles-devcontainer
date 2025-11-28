#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  APPLY="$REPO_ROOT/bin/apply"
}

teardown() {
  if [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]]; then
    rm -rf "$WORKDIR"
  fi
}

run_apply() {
  local name="$1" repo="$2" branch="$3" shell="$4" profile="$5"
  WORKDIR="$(mktemp -d "/tmp/devcontainer-${name}-XXXX")"

  local env_args=(
    "DOTFILES_REPO=$repo"
    "DOTFILES_BRANCH=$branch"
    "USER_SHELL=$shell"
    "VERBOSE=true"
  )
  if [[ -n "$profile" ]]; then
    env_args+=("USER_SHELL_NAME=$profile")
  fi

  run env "${env_args[@]}" bash -x "$APPLY" --repo "$repo" --branch "$branch" --shell "$shell" "$WORKDIR"
  if [[ "$status" -ne 0 ]]; then
    echo "apply failed (name=$name):"
    echo "$output"
    if [[ -d "$WORKDIR/.devcontainer" ]]; then
      echo "contents of .devcontainer after failure:"
      find "$WORKDIR/.devcontainer" -maxdepth 1 -type f -print -exec sed -n '1,120p' {} \;
    fi
  fi
  [ "$status" -eq 0 ]
}

json_get() {
  local file="$1" path="$2"
  node - "$file" "$path" <<'NODE'
const fs = require('fs');
const [file, pathStr] = process.argv.slice(2);
const raw = fs.readFileSync(file, 'utf8');
// Strip full-line // comments (devcontainer.json allows them)
const cleaned = raw.replace(/^\s*\/\/.*$/gm, '');
const obj = JSON.parse(cleaned);
const parts = [];
let buf = '';
let escape = false;
for (const ch of pathStr) {
  if (escape) {
    buf += ch;
    escape = false;
    continue;
  }
  if (ch === '\\') {
    escape = true;
    continue;
  }
  if (ch === '.') {
    parts.push(buf);
    buf = '';
    continue;
  }
  buf += ch;
}
if (buf) parts.push(buf);
const val = parts.reduce((o, k) => (o && Object.prototype.hasOwnProperty.call(o, k) ? o[k] : undefined), obj);
if (val === undefined) {
  console.error(`Missing path '${pathStr}' in ${file}`);
  process.exit(1);
}
if (typeof val === 'object') {
  console.log(JSON.stringify(val));
} else {
  console.log(String(val));
}
NODE
}

assert_common_state() {
  local repo="$1" branch="$2" shell="$3" profile="$4"

  # No unresolved template placeholders in files we rewrite
  run rg -F '${templateOption' "$WORKDIR/.devcontainer/Dockerfile"
  if [[ "$status" -eq 0 ]]; then
    echo "found template placeholders in Dockerfile"
    echo "$output"
    return 1
  fi
  run rg -F '${templateOption' "$WORKDIR/.devcontainer/post-create.sh"
  if [[ "$status" -eq 0 ]]; then
    echo "found template placeholders in post-create.sh"
    echo "$output"
    return 1
  fi

  if [[ ! -f "$WORKDIR/.devcontainer/Dockerfile" ]]; then
    echo "Dockerfile missing from apply output"
    return 1
  fi

  local dc_json="$WORKDIR/.devcontainer/devcontainer.json"
  local repo_arg
  repo_arg="$(json_get "$dc_json" 'build.args.DOTFILES_REPO')"
  if [[ "$repo_arg" != "$repo" ]]; then
    echo "repo mismatch: expected $repo got $repo_arg"
    return 1
  fi
  local branch_arg
  branch_arg="$(json_get "$dc_json" 'build.args.DOTFILES_BRANCH')"
  if [[ "$branch_arg" != "$branch" ]]; then
    echo "branch mismatch: expected $branch got $branch_arg"
    return 1
  fi
  local shell_arg
  shell_arg="$(json_get "$dc_json" 'build.args.USER_SHELL')"
  if [[ "$shell_arg" != "$shell" ]]; then
    echo "shell mismatch: expected $shell got $shell_arg"
    return 1
  fi
  local profile_arg
  profile_arg="$(json_get "$dc_json" 'customizations.vscode.settings.terminal\.integrated\.defaultProfile\.linux')"
  if [[ "$profile_arg" != "$profile" ]]; then
    echo "profile mismatch: expected $profile got $profile_arg"
    return 1
  fi

  run rg -F 'chsh -s "${USER_SHELL}"' "$WORKDIR/.devcontainer/Dockerfile"
  if [[ "$status" -ne 0 ]]; then
    echo "missing chsh using USER_SHELL"
    echo "$output"
    return 1
  fi

  run rg -F "$repo" "$WORKDIR/.devcontainer/post-create.sh"
  if [[ "$status" -ne 0 ]]; then
    echo "repo not found in post-create.sh"
    echo "$output"
    return 1
  fi
  run rg -F "$branch" "$WORKDIR/.devcontainer/post-create.sh"
  if [[ "$status" -ne 0 ]]; then
    echo "branch not found in post-create.sh"
    echo "$output"
    return 1
  fi
}

@test "default templating stays generic" {
  run_apply default "https://github.com/technicalpickles/dotfiles.git" "main" "/usr/bin/fish" ""
  # profile should derive from shell basename (fish)
  assert_common_state "https://github.com/technicalpickles/dotfiles.git" "main" "/usr/bin/fish" "fish"
}

@test "shell override via env" {
  run_apply bashenv "https://github.com/example/dots.git" "custom" "/bin/bash" "bash"
  assert_common_state "https://github.com/example/dots.git" "custom" "/bin/bash" "bash"
}

@test "profile name derived from shell path when not provided" {
  run_apply zsh-derived "https://github.com/example/dots.git" "main" "/bin/zsh" ""
  assert_common_state "https://github.com/example/dots.git" "main" "/bin/zsh" "zsh"
}
