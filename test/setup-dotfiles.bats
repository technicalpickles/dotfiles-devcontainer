#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SETUP_DOTFILES="$REPO_ROOT/docker/base/setup-dotfiles"
  mkdir -p "$REPO_ROOT/tmp"
  TEST_TMPDIR="$(mktemp -d "${REPO_ROOT}/tmp/setup-dotfiles-XXXX")"
}

teardown() {
  if [[ -n "${TEST_TMPDIR:-}" && -d "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR"
  fi
}

create_yes_required_repo() {
  local repo_dir="$TEST_TMPDIR/yes-required-dotfiles"
  mkdir -p "$repo_dir"

  cat >"$repo_dir/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "--yes" ]]; then
  echo "missing --yes" >&2
  exit 42
fi

touch "${HOME}/.install-ran"
EOF
  chmod +x "$repo_dir/install.sh"

  (
    cd "$repo_dir" || exit 1
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -b main >/dev/null
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.email "fixture@example.com"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.name "Fixture User"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git add install.sh >/dev/null
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git commit -m "fixture" >/dev/null
  )

  printf '%s\n' "$repo_dir"
}

@test "setup-dotfiles passes explicit install args through to install.sh" {
  local repo_dir
  local home_dir="$TEST_TMPDIR/home"
  repo_dir="$(create_yes_required_repo)"
  mkdir -p "$home_dir"

  run env HOME="$home_dir" bash "$SETUP_DOTFILES" \
    --repo "file://${repo_dir}" \
    --branch main \
    --install-arg --yes \
    --dest "$TEST_TMPDIR/dotfiles"

  [ "$status" -eq 0 ]
  [ -f "$home_dir/.install-ran" ]
}

@test "setup-dotfiles preserves argv boundaries across repeated install args" {
  local repo_dir="$TEST_TMPDIR/multi-arg-dotfiles"
  local home_dir="$TEST_TMPDIR/home"
  mkdir -p "$repo_dir"
  mkdir -p "$home_dir"

  cat >"$repo_dir/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$#" > "${HOME}/argc"
printf '%s\n' "$1" > "${HOME}/arg1"
printf '%s\n' "$2" > "${HOME}/arg2"
printf '%s\n' "$3" > "${HOME}/arg3"
EOF
  chmod +x "$repo_dir/install.sh"

  (
    cd "$repo_dir" || exit 1
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -b main >/dev/null
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.email "fixture@example.com"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.name "Fixture User"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git add install.sh >/dev/null
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git commit -m "fixture" >/dev/null
  )

  run env HOME="$home_dir" bash "$SETUP_DOTFILES" \
    --repo "file://${repo_dir}" \
    --branch main \
    --install-arg --mode \
    --install-arg fast \
    --install-arg --yes \
    --dest "$TEST_TMPDIR/dotfiles"

  [ "$status" -eq 0 ]
  [ "$(cat "$home_dir/argc")" = "3" ]
  [ "$(cat "$home_dir/arg1")" = "--mode" ]
  [ "$(cat "$home_dir/arg2")" = "fast" ]
  [ "$(cat "$home_dir/arg3")" = "--yes" ]
}

@test "setup-dotfiles parses install args from JSON" {
  local repo_dir="$TEST_TMPDIR/json-arg-dotfiles"
  local home_dir="$TEST_TMPDIR/home-json"
  mkdir -p "$repo_dir"
  mkdir -p "$home_dir"

  cat >"$repo_dir/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$#" > "${HOME}/argc"
printf '%s\n' "$1" > "${HOME}/arg1"
printf '%s\n' "$2" > "${HOME}/arg2"
printf '%s\n' "$3" > "${HOME}/arg3"
EOF
  chmod +x "$repo_dir/install.sh"

  (
    cd "$repo_dir" || exit 1
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -b main >/dev/null
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.email "fixture@example.com"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.name "Fixture User"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git add install.sh >/dev/null
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git commit -m "fixture" >/dev/null
  )

  run env HOME="$home_dir" bash "$SETUP_DOTFILES" \
    --repo "file://${repo_dir}" \
    --branch main \
    --install-args-json '["--mode","fast","--yes"]' \
    --dest "$TEST_TMPDIR/dotfiles-json"

  [ "$status" -eq 0 ]
  [ "$(cat "$home_dir/argc")" = "3" ]
  [ "$(cat "$home_dir/arg1")" = "--mode" ]
  [ "$(cat "$home_dir/arg2")" = "fast" ]
  [ "$(cat "$home_dir/arg3")" = "--yes" ]
}

@test "setup-dotfiles trusts cloned mise.toml before running install.sh" {
  local repo_dir="$TEST_TMPDIR/mise-dotfiles"
  local home_dir="$TEST_TMPDIR/home-mise"
  local bin_dir="$TEST_TMPDIR/bin"
  local mise_log="$TEST_TMPDIR/mise.log"
  mkdir -p "$repo_dir" "$home_dir" "$bin_dir"

  cat >"$repo_dir/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

touch "${HOME}/.install-ran"
EOF
  cat >"$repo_dir/mise.toml" <<'EOF'
[tools]
node = "lts"
EOF
  chmod +x "$repo_dir/install.sh"

  cat >"$bin_dir/mise" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$mise_log"
EOF
  chmod +x "$bin_dir/mise"

  (
    cd "$repo_dir" || exit 1
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git init -b main >/dev/null
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.email "fixture@example.com"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.name "Fixture User"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git add install.sh mise.toml >/dev/null
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git commit -m "fixture" >/dev/null
  )

  run env HOME="$home_dir" PATH="$bin_dir:/usr/bin:/bin" bash "$SETUP_DOTFILES" \
    --repo "file://${repo_dir}" \
    --branch main \
    --install-arg --yes \
    --dest "$TEST_TMPDIR/dotfiles-mise"

  [ "$status" -eq 0 ]
  [ -f "$home_dir/.install-ran" ]
  run cat "$mise_log"
  [ "$status" -eq 0 ]
  [ "$output" = "trust --yes $TEST_TMPDIR/dotfiles-mise/mise.toml" ]
}
