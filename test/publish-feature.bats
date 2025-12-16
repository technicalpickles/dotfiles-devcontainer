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
  # Note: --help requires a feature name first (any valid feature works)
  run "$PUBLISH" dind --help
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
