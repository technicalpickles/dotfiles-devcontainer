# Quickstart: Multi-arch base image support

1. Ensure Docker Buildx is available in CI (GitHub Actions public runners) and registry credentials are configured for publishing base images.
2. Build both architectures via the release workflow (ARM64 and X86/AMD64) and publish manifests to GHCR.
3. Run smoke/Goss tests for each architecture; fail the pipeline if any variant fails.
4. Run `bats test/apply.bats` to verify devcontainer template behavior and architecture selection messaging.
5. In devcontainer builds, reference the base image tag only; platform auto-selects. Use explicit override only for remote/CI mismatches.
6. Update docs to explain auto-selection, overrides, and how warnings surface when platforms are unsupported.
