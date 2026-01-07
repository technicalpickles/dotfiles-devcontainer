# DinD Feature Releases

## v0.1.1 (pending publish)

- Adds JSON publish summary (version/digest/mounts) from `bin/publish-feature`.
- Exports `DOCKER_HOST` in `start-dind.sh` to align with pinned base Docker bits and avoid socket drift.
- Publish via: `gh workflow run publish-feature.yml -f feature=dind` or `bin/publish-feature dind`.
- Digest: _TBD_ (run workflow and record from `tmp/dind-feature-publish.json`).
- Pinning: use `DIND_FEATURE_REF="ghcr.io/technicalpickles/devcontainer-features/dind@sha256:<digest>"` when applying or update `devcontainer.json` with the pinned digest snippet.

## v0.1.0

- Digest: `sha256:30eeba4b20d48247dde11bbab5b813a4b3748dc34014bebec46bf28e8b658020`
- Notes: Initial wiring-only DinD feature aligned to base image Docker bits; published via `publish-feature.yml`.
