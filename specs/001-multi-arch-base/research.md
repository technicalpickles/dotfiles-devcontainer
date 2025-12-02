# Research: Multi-arch base image support

## Decisions

- **Decision**: Build and publish ARM64 and X86/AMD64 base images on GitHub Actions public runners using Docker Buildx.
  - **Rationale**: Matches current CI environment, avoids self-hosted dependencies, and enables native multi-arch manifests.
  - **Alternatives considered**: Self-hosted ARM runners (adds infra overhead); separate pipelines per arch (more drift, slower feedback).

- **Decision**: Rely on Docker’s native platform warnings for unsupported architectures and add an apply-script warning when detection is unsure or unsupported.
  - **Rationale**: Keeps behavior aligned with Docker defaults while surfacing clearer guidance in the template UX.
  - **Alternatives considered**: Custom platform detection logic (duplicates Docker behavior); silent fallback to emulation (risks slow/fragile builds).

- **Decision**: Block releases if either architecture’s smoke/Goss validation fails; do not publish partial or fallback images.
  - **Rationale**: Ensures both variants remain healthy and prevents ambiguous tags in the registry.
  - **Alternatives considered**: Publish healthy variant only (creates tag ambiguity); auto-fallback to emulation (defeats native support goals).

- **Decision**: Users specify only the base image tag; architecture auto-selects with an opt-in override for remote/CI workflows.
  - **Rationale**: Simplifies UX, aligns with devcontainer expectations, and keeps platform choice automatic for common cases.
  - **Alternatives considered**: Require explicit platform flags in user config (more friction; higher support burden).
