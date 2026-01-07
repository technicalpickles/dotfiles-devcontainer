# .github/workflows/ - CI/CD

GitHub Actions workflows for testing, building, and publishing.

## References

@docs/ci.md
@specs/001-multi-arch-base/spec.md

## Workflows

### test-pr.yaml

Runs on PRs. Detects changes and runs appropriate validations:

- Dotfiles changes → smoke test
- Feature changes → dry-run publish validation

### base-image-publish.yaml

Multi-architecture base image build and publish:

- Triggers: push to main, weekly schedule, manual
- Builds linux/amd64 and linux/arm64
- Tests each with Goss before promotion
- Publishes to GHCR with candidate → release promotion

### publish-feature.yml

Manual workflow to publish individual features to GHCR. Accepts `feature` input (e.g., `dind`, `aws-cli`, `claude-code`) with optional `version` override and `dry-run` mode.

### bats-tests.yaml

Runs BATS test suite on PRs.

### release.yaml

Template release using devcontainers/action@v1.

## Patterns

### Multi-Arch Builds

```yaml
- uses: docker/setup-qemu-action@v3
- uses: docker/setup-buildx-action@v3
- uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
```

### GHCR Authentication

Requires `write:packages` scope. Use `GITHUB_TOKEN` or `GHCR_PAT` secret.

### Validation Gate

Publication blocks if any architecture fails validation. Only promote tested candidates.
