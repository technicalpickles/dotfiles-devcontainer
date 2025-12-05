# DinD Feature Releases

## v0.1.1 (pending publish)

- Adds JSON publish summary (version/digest/mounts) from `bin/publish-dind-feature` / `publish-dind-feature.yml`.
- Exports `DOCKER_HOST` in `start-dind.sh` to align with pinned base Docker bits and avoid socket drift.
- Workflows: `publish-dind-feature.yml` (package/publish with bats + Goss) and `pin-dind-feature.yml` (digest resolution helper).
- Digest: _TBD_ (run `publish-dind-feature.yml` and record from `tmp/dind-feature-publish.json`).
- Pinning: use `DIND_FEATURE_REF="ghcr.io/technicalpickles/devcontainer-features/dind@sha256:<digest>"` when applying or update `devcontainer.json` with the pinned digest snippet.

## v0.1.0

- Digest: `sha256:30eeba4b20d48247dde11bbab5b813a4b3748dc34014bebec46bf28e8b658020`
- Notes: Initial wiring-only DinD feature aligned to base image Docker bits; published via `feature-publish.yaml`.
