# Quickstart – Publish and Consume DinD Feature

## Prerequisites

- Pinned base image digest from `ghcr.io/technicalpickles/dotfiles-devcontainer/base`.
- Devcontainer CLI available in CI for packaging/publishing features.
- Access to GHCR namespace for pushing `devcontainer-features/dind`.

## Consume the published feature

1. Apply the template: `bin/apply` into a target repo (no `.devcontainer/features` vendoring expected).
2. Reference the feature in `devcontainer-template.json`:

   ```json
   "features": {
     "ghcr.io/technicalpickles/devcontainer-features/dind": {
       "version": "v0.1.0"
     }
   }
   ```

3. Build the devcontainer: `bin/build` (or VS Code/Codespaces reload) and verify Docker works without local feature files.
4. Pin or update: change `version` (or digest when published) to control upgrades; run `bin/build` again.

## Fallback when registry is unreachable

1. Retry with backoff; keep the pinned version/digest unchanged.
2. If outage persists, switch to a known-good digest (documented in release notes) in the `features` block.
3. Last resort: temporarily vendor the feature files locally with a note to remove once registry access returns.

## Publish and update template reference

1. Package + publish from CI: `devcontainer features publish ./src/dotfiles/.devcontainer/features/dind --registry ghcr.io/technicalpickles --namespace devcontainer-features`.
2. Verify publish output (version, digest) and update the template `features` reference accordingly.
3. Run `bats test/apply.bats` to confirm template builds with the published feature; keep base-image Goss smoke passing for Docker component alignment.
4. Document the new version and fallback digest in release notes and `devcontainer-template.json` comments if present.
