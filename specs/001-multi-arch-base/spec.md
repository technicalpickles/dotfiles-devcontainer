# Feature Specification: Multi-arch base image support

**Feature Branch**: `[001-multi-arch-base]`
**Created**: 2025-12-01
**Status**: Draft
**Input**: User description: "should support both base images for both ARM64 and X86/AMD64, in order to have better support on Apple Silicon hardware"

**Constitution Alignment**: Keeps the devcontainer template generic so users layer their own dotfiles/shell on top of the base image and `setup-dotfiles`. Extending to multi-architecture publishing preserves read-only credential boundaries (no additional secrets baked in) and relies solely on the base image plus user-provided setup. Automated checks to update/add: ensure base-image smoke/Goss coverage runs for both ARM64 and X86/AMD64 builds, and expand `bats test/apply.bats` (or equivalent release gate) to verify architecture selection and tagging. Documentation must note the dual-arch availability, host-architecture defaults, and any steps for remote/CI environments.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Apple Silicon devcontainer build works natively (Priority: P1)

Apple Silicon developers can start a devcontainer using a native ARM64 base image without extra configuration or emulation.

**Why this priority**: Eliminates slow emulation workflows and unblocks the largest affected user group.

**Independent Test**: Building and launching a devcontainer on an Apple Silicon host succeeds using the native base image with standard setup steps.

**Acceptance Scenarios**:

1. **Given** an Apple Silicon host using the published devcontainer definition, **When** the container is built, **Then** the ARM64 base image is selected automatically and the container launches without emulation warnings.
2. **Given** an Apple Silicon host, **When** the devcontainer build completes, **Then** core setup tasks (e.g., invoking `setup-dotfiles`) run successfully on the ARM64 base image.

---

### User Story 2 - Release maintainers publish both architectures (Priority: P2)

Release maintainers can build, verify, and publish both ARM64 and X86/AMD64 base images in the standard release process.

**Why this priority**: Ensures both architectures remain supported and prevents regressions in future releases.

**Independent Test**: Running the release pipeline produces both architecture variants with verification steps and tags that are discoverable and documented.

**Acceptance Scenarios**:

1. **Given** a release candidate, **When** the release pipeline runs, **Then** both ARM64 and X86/AMD64 base images are built, pass smoke checks, and are tagged in a predictable scheme.

---

### User Story 3 - Intel users remain unaffected (Priority: P3)

Developers on X86/AMD64 machines continue to use the base image without new steps or regressions.

**Why this priority**: Maintains stability for existing users while adding Apple Silicon support.

**Independent Test**: Building a devcontainer on an X86/AMD64 host continues to select the matching base image and complete setup as before.

**Acceptance Scenarios**:

1. **Given** an X86/AMD64 host using the published devcontainer definition, **When** the container is built, **Then** the X86/AMD64 base image is used and the build completes successfully.

---

### Edge Cases

- Hosts that report an unexpected architecture string rely on Docker’s native platform warning; the apply script should also warn when an unsupported platform is detected rather than proceeding silently.
- Remote/CI environments where the build host differs from the developer workstation must allow explicit architecture selection without editing the base image definition.
- If one architecture image fails a smoke check, release must block that variant and fail the release rather than promoting it; the healthy variant should not be replaced or silently used as a fallback.
- Tagging scheme collisions (e.g., same tag used for different architectures) must be prevented or rejected.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: Publish and maintain base image variants for both ARM64 and X86/AMD64 with consistent tagging and discovery.
- **FR-002**: Devcontainer builds must automatically select the matching base image for the host architecture while allowing an explicit override for remote/CI use, with users only needing to specify a base image tag (not a platform).
- **FR-003**: Both architecture variants must pass the same smoke and compatibility checks (including dotfile setup and core tooling availability) before release.
- **FR-004**: Release or nightly processes must fail fast when either architecture variant is missing or fails validation, without silently falling back to emulation or promoting a partial release.
- **FR-005**: Documentation must clearly state how architecture selection works, how to override it, and where to find both image variants.
- **FR-006**: Error messaging must guide users when their requested or detected architecture is unsupported or unavailable, including next steps; the apply script should warn if the detected platform is unsupported.

### Key Entities _(include if feature involves data)_

- **Base image variant**: Represents a published base image, identified by architecture and tag; must note compatibility expectations (e.g., host type) and validation status.
- **Release artifact record**: Captures the set of published variants per release, including architecture, tag, and validation outcome, for traceability.

### Dependencies and Assumptions

- Build and release infrastructure can produce and publish both ARM64 and X86/AMD64 variants without introducing new secrets.
- Host architecture detection is available during devcontainer build, with a user-selectable override when the build host and developer workstation differ.
- Distribution endpoints for the base images can surface architecture-specific tags and metadata for discovery.
- CI runs on GitHub Actions using default public runners; the multi-arch build and validation flow must work within those runner capabilities without requiring self-hosted hardware.
- Users reference base image tags without needing to specify platform details in typical workflows.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: 95% of Apple Silicon devcontainer builds complete successfully on the first attempt using the native ARM64 image without manual steps.
- **SC-002**: Devcontainer build and startup times on Apple Silicon remain within 5 minutes for the base template (parity with or better than X86/AMD64 builds).
- **SC-003**: Each release produces and records validated ARM64 and X86/AMD64 base images with no missing or ambiguous tags.
- **SC-004**: Support contacts related to architecture incompatibility or emulation workarounds decrease by at least 50% in the subsequent release cycle.
