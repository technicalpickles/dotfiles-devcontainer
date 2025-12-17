# test/ Directory

Testing infrastructure for the devcontainer template and features.

## References

@docs/devcontainer-cli.md
@docs/retrospectives/2025-12-08-devcontainer-hang.md

## Test Types

### BATS Tests (Unit)

```bash
bats test/apply.bats           # Tests for bin/apply
bats test/publish-feature.bats # Tests for bin/publish-feature
./bin/test-bats                # Run all BATS tests
```

### Integration Tests

- `test/dotfiles/test.sh` - Template integration tests (run inside container)
- `test/features/dind/test.sh` - Docker-in-Docker wiring verification
- `test/features/aws-cli/test.sh` - AWS credentials mount verification

## Fixtures

`test/fixtures/` contains test data:

- `simple-dotfiles/` - Minimal dotfiles repo for testing

## Test Utilities

`test/test-utils/` contains shared test helpers.

## Running Tests

```bash
# Unit tests
bats test/apply.bats

# Full smoke test (builds container, runs integration tests)
./bin/smoke-test

# Keep artifacts for debugging
./bin/smoke-test --keep-artifacts
```

## Writing Tests

BATS tests use the `dotfiles_fixture` loader pattern. See existing tests for examples.
