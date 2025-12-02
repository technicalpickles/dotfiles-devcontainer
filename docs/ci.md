# CI Reference: Multi-arch base image publishing

## GitHub Actions runner capabilities

- Default GitHub Actions public runners support Docker Buildx and QEMU via `docker/setup-buildx-action` and `docker/setup-qemu-action`; no self-hosted hardware is required.
- Runners already include Docker CLI; ensure Buildx driver is initialized in the workflow before multi-arch builds.
- Use manifest pushes to publish both ARM64 and X86/AMD64 variants to GHCR in a single workflow execution.

## Registry credentials (GHCR)

- Publishing to GHCR must use a token with `write:packages` scope (e.g., `GITHUB_TOKEN` when the repo allows package publishing, or a `GHCR_PAT` secret).
- Workflow should log in to `ghcr.io` before builds/pushes; fail fast if credentials are missing.
- Confirm secrets are present in repository settings before running release workflows.

## Release workflow expectations

- Build multi-architecture candidates (ARM64 and X86/AMD64) with Buildx, then run smoke/Goss per architecture before promotion.
- Publication must block if any architecture fails validation; only promote the tested candidate manifest to release tags.
- Record per-architecture digests and release tags (step summary) for traceability.
