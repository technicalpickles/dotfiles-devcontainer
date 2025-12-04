# Quickstart – Publish and Consume DinD Feature

## Prerequisites

- Pinned base image digest from `ghcr.io/technicalpickles/dotfiles-devcontainer/base`.
- Devcontainer CLI available in CI for packaging/publishing features.
- Access to GHCR namespace for pushing `devcontainer-features/dind`.

## Consume the published feature

1. Apply the template: `bin/apply` into a target repo (no `.devcontainer/features` vendoring expected).
2. Reference the feature in `src/dotfiles/.devcontainer/devcontainer.json` (start from the latest released tag when creating the template):

   ```json
   "features": {
     "ghcr.io/technicalpickles/devcontainer-features/dind:0.1.1": {}
   }
   ```

3. Verify the template wiring points to the remote feature and prebaked base image:

   ```sh
   test ! -d .devcontainer/features
   rg "devcontainer-features/dind" .devcontainer/devcontainer.json
   rg "dotfiles-devcontainer/base@sha256" .devcontainer/Dockerfile
   ```

4. Build the devcontainer: `bin/build` (or VS Code/Codespaces reload) and verify Docker works without local feature files.
5. Pin or update: change the version tag (or switch to a digest like `ghcr.io/.../dind@sha256:<digest>`) in the `features` block; run `bin/build` again. CI/release flows must resolve and pin the digest for deterministic builds.

## Capture performance baseline (apply + build)

1. From repo root, apply the template to a temp directory and time the run:

   ```sh
   time DOTFILES_REPO=https://github.com/technicalpickles/dotfiles.git DOTFILES_BRANCH=main USER_SHELL=/usr/bin/fish VERBOSE=true bin/apply /tmp/dind-baseline
   ```

2. From the applied temp directory, build the devcontainer and time the build:

   ```sh
   cd /tmp/dind-baseline
   time bin/build
   ```

3. After the build finishes, verify Docker works without vendored feature files:

   ```sh
   docker info
   ```

4. Record apply/build durations, Docker verification result, base image digest, and feature version/digest in `docs/dind-feature.md` under the Performance baseline and Published versions sections.
5. Target tolerance: stay within +10% or +30s (whichever is greater) of the recorded baseline on GH Actions public runners.

## Fallback when registry is unreachable

1. Retry with backoff; keep the pinned version/digest unchanged.
2. Use `.github/workflows/pin-dind-feature.yml` (or the JSON from `publish-dind-feature.yml`) to resolve a digest, then rerun `bin/apply` with `DIND_FEATURE_REF="ghcr.io/technicalpickles/devcontainer-features/dind@sha256:<digest>"` to pin deterministically in CI/release.
3. If outage persists, switch to a known-good digest (documented in release notes) in the `features` block.
4. Last resort: temporarily vendor the feature files locally with a note to remove once registry access returns.

## Publish and update template reference

1. Package + publish from CI via `.github/workflows/publish-dind-feature.yml` (uses `bin/publish-dind-feature`), or locally: `devcontainer features publish ./src/dotfiles/.devcontainer/features/dind --registry ghcr.io/technicalpickles --namespace devcontainer-features`.
2. Verify publish output (version, digest) and update the template `features` reference accordingly (record the resolved digest even if the template starts from the latest released tag).
3. Run `bats test/apply.bats` to confirm template builds with the published feature; keep base-image Goss smoke passing for Docker component alignment; confirm build time stays within +10% or +30s of baseline on GHA runners.
4. Document the new version and fallback digest in release notes and `src/dotfiles/.devcontainer/devcontainer.json` comments if present.
