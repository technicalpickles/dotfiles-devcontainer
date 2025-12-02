# Data Model – Publish DinD Feature

## Entities

### PublishedFeatureArtifact

- Fields: name/id, registry (`ghcr.io/technicalpickles/devcontainer-features/dind`), semver version, digest, wiring config (privileged flag, mounts, env defaults, entrypoint), compatibility notes with base image Docker bits, publish timestamp, validation results (package + tests), visibility.
- Relationships: consumed by DevcontainerTemplate; aligned to BaseImage Docker components.
- State: draft (local), published (available in registry), deprecated (superseded by newer version or incompatibility with base image).

### DevcontainerTemplate

- Fields: template version, base image digest, feature references (version/digest for DinD), dotfiles/shell options, fallback guidance for registry outages, validation results (`bats test/apply.bats`).
- Relationships: references PublishedFeatureArtifact; builds on BaseImage.
- State: draft -> validated (tests passing) -> released (template published).

### BaseImage

- Fields: image name, pinned digest, Docker engine/CLI versions baked in, setup-dotfiles invocation, user (`vscode`) and permissions, smoke test results (Goss).
- Relationships: provides Docker bits expected by PublishedFeatureArtifact; consumed by DevcontainerTemplate.

## Relationships

- DevcontainerTemplate **uses** PublishedFeatureArtifact to supply Docker-in-Docker wiring while keeping feature files out of consumer repos.
- PublishedFeatureArtifact **expects** Docker components from BaseImage; mismatch triggers compatibility risk.
- DevcontainerTemplate **pins** BaseImage digest to keep wiring + Docker bits aligned across publishes.

## Validation Rules

- Feature reference in DevcontainerTemplate must include explicit version/digest (no floating `latest`).
- PublishedFeatureArtifact publish must pass packaging/tests before updating template reference.
- BaseImage digest in template must match the version used during feature validation.
- Fallback guidance must be present when registry outages are detected/documented.
