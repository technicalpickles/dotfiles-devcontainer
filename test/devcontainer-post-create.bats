#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  DEVCONTAINER_POST_CREATE="$REPO_ROOT/docker/base/devcontainer-post-create"
  TEST_TMPDIR="$(mktemp -d "/tmp/devcontainer-post-create-XXXX")"
  WORKSPACE_DIR="$TEST_TMPDIR/workspace"
  HOME_DIR="$TEST_TMPDIR/home"
  BIN_DIR="$TEST_TMPDIR/bin"
  LOG_DIR="$TEST_TMPDIR/logs"

  mkdir -p "$WORKSPACE_DIR/.devcontainer" "$HOME_DIR" "$BIN_DIR" "$LOG_DIR"

  cat >"$BIN_DIR/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$LOG_DIR/git.log"
EOF
  chmod +x "$BIN_DIR/git"

  cat >"$BIN_DIR/mise" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$LOG_DIR/mise.log"
EOF
  chmod +x "$BIN_DIR/mise"
}

teardown() {
  if [[ -n "${TEST_TMPDIR:-}" && -d "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR"
  fi
}

run_post_create() {
  run env \
    HOME="$HOME_DIR" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    WORKSPACE_DIR="$WORKSPACE_DIR" \
    SKIP_DOTFILES=1 \
    SKIP_FISH=1 \
    SKIP_SUBMODULES=1 \
    bash "$DEVCONTAINER_POST_CREATE"
}

@test "base post-create trusts workspace mise.toml when present" {
  touch "$WORKSPACE_DIR/mise.toml"

  run_post_create

  [ "$status" -eq 0 ]
  [ -f "$LOG_DIR/mise.log" ]
  run cat "$LOG_DIR/mise.log"
  [ "$status" -eq 0 ]
  [ "$output" = "trust --yes $WORKSPACE_DIR/mise.toml" ]
}

@test "base post-create skips mise trust when workspace mise.toml is absent" {
  run_post_create

  [ "$status" -eq 0 ]
  [ ! -f "$LOG_DIR/mise.log" ]
}
