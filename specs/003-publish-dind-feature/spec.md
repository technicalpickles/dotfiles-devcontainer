# Feature Specification: Publish DinD Feature for Dotfiles Devcontainer

**Feature Branch**: `003-publish-dind-feature`
**Created**: 2025-12-02
**Status**: In Review
**Input**: User description: "based on this convesration to start extracting publishable features"

**Constitution Alignment**: Feature artifacts are published (not copied) to keep applied repos clean and generic; base image with `setup-dotfiles` still owns Docker tooling install; devcontainer config remains user-owned for shell/dotfiles options; read-only credential mounts stay unchanged; automated checks extend to cover published feature availability, template apply/build (bats), and base-image smoke/Goss where Docker bits are baked.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Consume published DinD feature (Priority: P1)

Template users can apply the devcontainer and have Docker-in-Docker wiring fetched from a published feature without copying feature files into their repo; builds remain fast because Docker bits are already in the base image.

**Why this priority**: Directly reduces devcontainer build time and keeps consuming repos uncluttered while preserving Docker functionality.

**Independent Test**: Apply the template to a clean repo, build the devcontainer, and verify Docker works without a local `.devcontainer/features` folder being added.

**Acceptance Scenarios**:

1. **Given** a repo with the template applied, **When** the devcontainer builds, **Then** Docker is available and no feature assets are copied into the repo.
2. **Given** a user opening the devcontainer, **When** Docker commands run, **Then** they succeed using the prebaked daemon bits from the base image.

---

### User Story 2 - Publish and version the feature (Priority: P2)

Maintainers can publish the Docker-in-Docker feature to the aligned registry namespace with a clear version, so consumers can pin or update predictably.

**Why this priority**: Enables repeatable pulls, pinning, and updates without manual copying; critical for distribution.

**Independent Test**: Run the publish flow and confirm the feature version is available in the registry and referenced in the template.

**Acceptance Scenarios**:

1. **Given** a new feature version, **When** it is published, **Then** the registry shows the new version and the template reference updates accordingly.

---

### User Story 3 - Pin and recover from registry issues (Priority: P3)

Consumers can pin a specific published feature version/digest and have guidance for fallbacks if the registry is temporarily unavailable.

**Why this priority**: Ensures stability and continuity during outages or breaking changes.

**Independent Test**: Configure the template to pin a specific feature version, simulate a registry fetch failure, and verify documented fallback guidance is available.

**Acceptance Scenarios**:

1. **Given** a pinned feature version, **When** the registry is reachable, **Then** the devcontainer builds using that version without pulling newer variants.
2. **Given** a registry outage, **When** a user follows documented guidance, **Then** they can continue work or know how to retry once available.

### Edge Cases

- Registry for the published feature is unreachable during devcontainer build.
- Template consumers pin a feature version that does not match the base image’s baked Docker tooling.
- Host or platform disallows privileged containers required for Docker-in-Docker wiring.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: Provide a published Docker-in-Docker feature in the aligned namespace so devcontainers can pull it without copying feature files.
- **FR-002**: Reference the published feature in the template so applied repos stay free of embedded feature assets while retaining Docker functionality.
- **FR-003**: Ensure the published feature conveys required Docker wiring (privileged, entrypoint, mounts, environment) that matches the Docker bits already baked into the base image.
- **FR-004**: Document how consumers pin specific feature versions/digests and how maintainers update the reference when publishing new versions.
- **FR-005**: Establish a repeatable publish process (including validation steps) that produces a visible versioned artifact in the registry.

### Key Entities _(include if feature involves data)_

- **Published feature artifact**: Versioned Docker-in-Docker wiring made available in the registry.
- **Devcontainer template**: Configuration that consumes the published feature while relying on the base image for Docker tooling.
- **Base image**: Prebaked Docker components that pair with the published feature’s wiring expectations.

### Assumptions

- Base image continues to bake Docker engine components compatible with the published wiring.
- Registry access to the aligned namespace is available to publishers and consumers.
- Devcontainer hosts permit privileged containers required for Docker-in-Docker scenarios.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: Devcontainer builds after applying the template complete without adding a `.devcontainer/features` folder to the target repo in 100% of test runs.
- **SC-002**: Published feature versions are discoverable in the registry with clear version identifiers within one publish attempt.
- **SC-003**: Consumers can pin or update the feature by changing a single version/digest reference and successfully build in 2 or fewer attempts.
- **SC-004**: Documented fallback guidance allows users to proceed or retry after a registry outage with no more than one additional documented step.

## Non-Functional Requirements

- **NFR-001**: Deterministic builds only; template pins the base image digest and the DinD feature version/digest (no floating `latest` tags).
- **NFR-002**: Publish/validation runs must succeed on default GitHub Actions public runners without self-hosted hardware or additional secrets beyond GHCR write scope.
- **NFR-003**: No new secrets or writable host mounts are introduced; host `~/.aws` stays read-only and privileged use is scoped to DinD wiring only.
- **NFR-004**: Devcontainer builds that pull the published feature complete within typical template timings (no material slowdown versus pre-publish wiring) and avoid duplicating Docker engine bits already in the base image.

## Dependencies & Constraints

- Base image: `ghcr.io/technicalpickles/dotfiles-devcontainer/base` (pinned digest, retains `vscode` UID/GID) with Docker engine bits baked in.
- Registry: GHCR availability for `ghcr.io/technicalpickles/devcontainer-features/dind`; consumers and CI need pull/push access as appropriate.
- Tooling: Devcontainer CLI with feature packaging/publishing support, Docker/Buildx on GitHub Actions runners, and existing bats/Goss harnesses.
- Credential boundary: host `~/.aws` mount remains read-only; no baked secrets or writable host mounts are permitted without review.

## Risks & Mitigations

- **Drift between base image Docker bits and published wiring** — Mitigate by running Goss/base smoke checks against the pinned base image digest during publish validation and documenting the validated digest.
- **GHCR outage or feature unavailability** — Mitigate with pinned version/digest references, documented fallback steps (retry, digest pin, temporary vendor with cleanup), and avoiding floating tags.
- **Hosts disallowing privileged containers** — Mitigate by clearly documenting that Docker-in-Docker requires privileged containers and offering guidance to fall back to non-DinD workflows when unsupported.

## Outstanding Items (post-PR follow-up)

- Record the first published DinD feature version/digest in `docs/dind-feature.md` and update the `devcontainer.json` feature reference accordingly once publish output is confirmed.
- Run/record validation results (`devcontainer features package/publish` summary, `bats test/apply.bats`, feature test harness) and capture them in `docs/dind-feature.md` and release notes.
