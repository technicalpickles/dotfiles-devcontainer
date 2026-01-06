#!/usr/bin/env bats

load "./test-utils/dotfiles_fixture"

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  APPLY="$REPO_ROOT/bin/apply"
}

teardown() {
  if [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]]; then
    rm -rf "$WORKDIR"
  fi
  cleanup_dotfiles_fixtures
}

run_apply() {
  local name="$1" repo="$2" branch="$3" shell="$4" profile="$5" platform="${6:-}"
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
  if [[ -n "$platform" ]]; then
    env_args+=("PLATFORM_OVERRIDE=$platform")
  fi

  local platform_args=()
  if [[ -n "$platform" ]]; then
    platform_args+=(--platform "$platform")
  fi

  run env "${env_args[@]}" bash -x "$APPLY" ci-unpinned --repo "$repo" --branch "$branch" --shell "$shell" "${platform_args[@]}" "$WORKDIR"
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
  run rg -F "devcontainer-post-create" "$WORKDIR/.devcontainer/post-create.sh"
  if [[ "$status" -ne 0 ]]; then
    echo "base entrypoint delegation missing in post-create.sh"
    echo "$output"
    return 1
  fi
}

@test "default templating stays generic" {
  local repo_dir
  repo_dir="$(create_dotfiles_fixture_repo)"
  local repo_url="file://${repo_dir}"

  run_apply default "$repo_url" "main" "/usr/bin/fish" ""
  assert_common_state "$repo_url" "main" "/usr/bin/fish" "fish"
}

@test "dind feature references ghcr and is not vendored" {
  local repo_dir
  repo_dir="$(create_dotfiles_fixture_repo)"
  local repo_url="file://${repo_dir}"

  run_apply dind-ghcr "$repo_url" "main" "/usr/bin/fish" ""
  [ "$status" -eq 0 ]

  [ ! -d "$WORKDIR/.devcontainer/features" ]

  local dc_json="$WORKDIR/.devcontainer/devcontainer.json"
  if [[ ! -f "$dc_json" ]]; then
    echo "missing devcontainer.json at $dc_json"
  fi
  run node - "$dc_json" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
const raw = fs.readFileSync(path, 'utf8').replace(/^\s*\/\/.*$/gm, '');
const obj = JSON.parse(raw);
const dindRef = "ghcr.io/technicalpickles/devcontainer-features/dind:0.1.1";
const awsCliRef = "ghcr.io/technicalpickles/devcontainer-features/aws-cli:0.1.0";
const features = obj.features || {};
const keys = Object.keys(features);
if (keys.length !== 2 || !features[dindRef] || !features[awsCliRef]) {
  console.error('feature reference mismatch', features);
  process.exit(1);
}
NODE
  if [[ "$status" -ne 0 ]]; then
    echo "$output"
  fi
  [ "$status" -eq 0 ]

  run node - "$dc_json" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
const raw = fs.readFileSync(path, 'utf8').replace(/^\s*\/\/.*$/gm, '');
const obj = JSON.parse(raw);
const dockerBuildArg = ((obj.build || {}).args || {}).DOCKER_BUILD;
if (dockerBuildArg !== 'true') {
  console.error('DOCKER_BUILD arg not enforced for prebaked Docker bits', dockerBuildArg);
  process.exit(1);
}
NODE
  [ "$status" -eq 0 ]

  # Base image can be pinned by SHA256 or use :latest tag
  run rg -n "ghcr.io/technicalpickles/dotfiles-devcontainer/base(:|@sha256:)" "$WORKDIR/.devcontainer/Dockerfile"
  [ "$status" -eq 0 ]
}

@test "pinned DinD digest can override feature ref for fallback" {
  local repo_dir
  repo_dir="$(create_dotfiles_fixture_repo)"
  local repo_url="file://${repo_dir}"
  local pinned_ref="ghcr.io/technicalpickles/devcontainer-features/dind@sha256:deadbeef"

  DIND_FEATURE_REF="$pinned_ref" run_apply dind-pinned "$repo_url" "main" "/usr/bin/fish" ""
  [ "$status" -eq 0 ]

  [ ! -d "$WORKDIR/.devcontainer/features" ]

  local dc_json="$WORKDIR/.devcontainer/devcontainer.json"
  local aws_cli_ref="ghcr.io/technicalpickles/devcontainer-features/aws-cli:0.1.0"
  run node - "$dc_json" "$pinned_ref" "$aws_cli_ref" <<'NODE'
const fs = require('fs');
const [file, dindRef, awsCliRef] = process.argv.slice(2);
const raw = fs.readFileSync(file, 'utf8').replace(/^\s*\/\/.*$/gm, '');
const obj = JSON.parse(raw);
const features = obj.features || {};
const keys = Object.keys(features);
if (keys.length !== 2 || !features[dindRef] || !features[awsCliRef]) {
  console.error('pinned ref mismatch', features);
  process.exit(1);
}
NODE
  [ "$status" -eq 0 ]
}

@test "shell override via env" {
  run_apply bashenv "https://github.com/example/dots.git" "custom" "/bin/bash" "bash"
  assert_common_state "https://github.com/example/dots.git" "custom" "/bin/bash" "bash"
}

@test "profile name derived from shell path when not provided" {
  local repo_dir
  repo_dir="$(create_dotfiles_fixture_repo)"
  local repo_url="file://${repo_dir}"

  run_apply zsh-derived "$repo_url" "main" "/bin/zsh" ""
  assert_common_state "$repo_url" "main" "/bin/zsh" "zsh"
}

@test "platform auto-detected and recorded in devcontainer build options" {
  local expected_platform=""
  case "$(uname -m)" in
    arm64|aarch64) expected_platform="linux/arm64" ;;
    x86_64|amd64) expected_platform="linux/amd64" ;;
  esac
  if [[ -z "$expected_platform" ]]; then
    skip "unknown host arch for platform detection test"
  fi

  local repo_dir
  repo_dir="$(create_dotfiles_fixture_repo)"
  local repo_url="file://${repo_dir}"

  run_apply platform-auto "$repo_url" "main" "/usr/bin/fish" ""
  [ "$status" -eq 0 ]

  local dc_json="$WORKDIR/.devcontainer/devcontainer.json"
  run node - "$dc_json" "$expected_platform" <<'NODE'
const fs = require('fs');
const [file, expected] = process.argv.slice(2);
const raw = fs.readFileSync(file, 'utf8').replace(/^\s*\/\/.*$/gm, '');
const obj = JSON.parse(raw);
const opts = (obj.build && obj.build.options) || [];
if (!opts.includes(`--platform=${expected}`)) {
  console.error('missing platform flag', opts);
  process.exit(1);
}
NODE
  [ "$status" -eq 0 ]
}

@test "platform override forces requested platform in build options" {
  run_apply platform-override "https://github.com/example/dots.git" "main" "/usr/bin/fish" "" "linux/arm64"
  [ "$status" -eq 0 ]

  local dc_json="$WORKDIR/.devcontainer/devcontainer.json"
  run node - "$dc_json" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const raw = fs.readFileSync(file, 'utf8').replace(/^\s*\/\/.*$/gm, '');
const obj = JSON.parse(raw);
const opts = (obj.build && obj.build.options) || [];
if (!opts.includes('--platform=linux/arm64')) {
  console.error('missing override flag', opts);
  process.exit(1);
}
NODE
  [ "$status" -eq 0 ]
}

@test "post-create fails clearly when base entrypoint is missing" {
  run_apply missing-base "https://github.com/example/dots.git" "main" "/usr/bin/fish" ""
  [ "$status" -eq 0 ]

  run /bin/bash "$WORKDIR/.devcontainer/post-create.sh"
  [ "$status" -ne 0 ]
  echo "$output"
  echo "$output" | /usr/bin/grep -q "Expected base entrypoint"
}

@test "post-create fails when base entrypoint exists but is not executable" {
  run_apply non-executable-base "https://github.com/example/dots.git" "main" "/usr/bin/fish" ""
  [ "$status" -eq 0 ]

  local fake_base="$WORKDIR/fake-devcontainer-post-create"
  echo "#!/usr/bin/env bash" > "$fake_base"
  chmod 644 "$fake_base"

  [ -f "$fake_base" ]
  [ ! -x "$fake_base" ]

  run env BASE_POST_CREATE="$fake_base" /bin/bash "$WORKDIR/.devcontainer/post-create.sh"
  [ "$status" -ne 0 ]
  echo "$output"
  echo "$output" | /usr/bin/grep -q "Expected base entrypoint"
}

@test "aws-cli feature references ghcr in applied config" {
  local repo_dir
  repo_dir="$(create_dotfiles_fixture_repo)"
  local repo_url="file://${repo_dir}"

  run_apply aws-cli-ghcr "$repo_url" "main" "/usr/bin/fish" ""
  [ "$status" -eq 0 ]

  local dc_json="$WORKDIR/.devcontainer/devcontainer.json"
  if [[ ! -f "$dc_json" ]]; then
    echo "missing devcontainer.json at $dc_json"
    return 1
  fi

  # Verify aws-cli feature is referenced
  run node - "$dc_json" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
const raw = fs.readFileSync(path, 'utf8').replace(/^\s*\/\/.*$/gm, '');
const obj = JSON.parse(raw);
const features = obj.features || {};
const keys = Object.keys(features);
const awsCliKey = keys.find(k => k.includes('aws-cli'));
if (!awsCliKey) {
  console.error('aws-cli feature not found in features:', keys);
  process.exit(1);
}
if (!awsCliKey.includes('ghcr.io')) {
  console.error('aws-cli feature does not reference ghcr:', awsCliKey);
  process.exit(1);
}
console.log('aws-cli feature found:', awsCliKey);
NODE
  if [[ "$status" -ne 0 ]]; then
    echo "$output"
  fi
  [ "$status" -eq 0 ]
}

@test "local-dev mode keeps vendored aws-cli feature" {
  local repo_dir
  repo_dir="$(create_dotfiles_fixture_repo)"
  local repo_url="file://${repo_dir}"

  WORKDIR="$(mktemp -d "/tmp/devcontainer-local-dev-XXXX")"
  run env DOTFILES_REPO="$repo_url" DOTFILES_BRANCH="main" USER_SHELL="/usr/bin/fish" \
    bash -x "$APPLY" local-dev --repo "$repo_url" --branch "main" --shell "/usr/bin/fish" "$WORKDIR"
  if [[ "$status" -ne 0 ]]; then
    echo "apply failed:"
    echo "$output"
  fi
  [ "$status" -eq 0 ]

  # Verify vendored features directory exists
  [ -d "$WORKDIR/.devcontainer/features" ]
  [ -d "$WORKDIR/.devcontainer/features/aws-cli" ]
  [ -f "$WORKDIR/.devcontainer/features/aws-cli/devcontainer-feature.json" ]

  # Verify aws-cli feature references local path
  local dc_json="$WORKDIR/.devcontainer/devcontainer.json"
  run node - "$dc_json" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
const raw = fs.readFileSync(path, 'utf8').replace(/^\s*\/\/.*$/gm, '');
const obj = JSON.parse(raw);
const features = obj.features || {};
const keys = Object.keys(features);
const awsCliKey = keys.find(k => k.includes('aws-cli'));
if (!awsCliKey) {
  console.error('aws-cli feature not found in features:', keys);
  process.exit(1);
}
if (!awsCliKey.startsWith('./')) {
  console.error('aws-cli feature should be local ref in local-dev mode:', awsCliKey);
  process.exit(1);
}
console.log('local aws-cli feature found:', awsCliKey);
NODE
  if [[ "$status" -ne 0 ]]; then
    echo "$output"
  fi
  [ "$status" -eq 0 ]
}
