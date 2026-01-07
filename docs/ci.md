# CI Reference: Multi-arch base image publishing

## GitHub Actions runner capabilities

- Default GitHub Actions public runners support Docker Buildx and QEMU via `docker/setup-buildx-action` and `docker/setup-qemu-action`; no self-hosted hardware is required.
- Runners already include Docker CLI; ensure Buildx driver is initialized in the workflow before multi-arch builds.
- Use manifest pushes to publish both ARM64 and X86/AMD64 variants to GHCR in a single workflow execution.

## Registry credentials (GHCR)

- Publishing to GHCR must use a token with `write:packages` scope (e.g., `GITHUB_TOKEN` when the repo allows package publishing, or a `GHCR_PAT` secret).
- Workflow should log in to `ghcr.io` before builds/pushes; fail fast if credentials are missing.
- Confirm secrets are present in repository settings before running release workflows.

## Feature publishing

- Publish any feature via workflow `.github/workflows/publish-feature.yml` (manual `workflow_dispatch`) or locally with `bin/publish-feature <name>`.
- Supported features: `dind`, `aws-cli`, `claude-code` (and future features).
- Workflow inputs: `feature` (required), `version` (optional override), `dry-run` (skip actual publish).
- Ensure Docker engine bits remain baked into the base image; features only wire configuration and metadata.
- Validation steps: `devcontainer features package` to confirm metadata; `test/features/<name>/test.sh` to sanity-check wiring; `bats test/apply.bats` to ensure template references the GHCR feature and does not vendor feature files.
- After publish: record version + digest in `docs/releases/<name>-feature.md` and verify `src/dotfiles/.devcontainer/devcontainer.json` references the published tag/digest.
- Smoke: `bin/smoke-test --base-image <tag-or-digest>` runs with the devcontainer CLI. Requires host Docker with `--privileged` support for DinD testing; override base image when testing local builds.

## Release workflow expectations

- Build multi-architecture candidates (ARM64 and X86/AMD64) with Buildx, then run smoke/Goss per architecture before promotion.
- Publication must block if any architecture fails validation; only promote the tested candidate manifest to release tags.
- Record per-architecture digests and release tags (step summary) for traceability.

## Devcontainer CLI usage

Local test scripts and CI workflows use `@devcontainers/cli` to build and run containers. See [devcontainer-cli.md](./devcontainer-cli.md) for detailed command behaviors and gotchas.

**Key point:** `devcontainer up` blocks indefinitely when starting a new container but exits immediately if one is already running. Scripts must account for this behavior.
