# Feature Specification: Base Post-Create Entrypoint Shim

**Feature Branch**: `002-post-create-script`
**Created**: 2025-12-02
**Status**: Draft
**Input**: User description: "this post-create.sh"

**Constitution Alignment**: Keeps devcontainer behavior generic by making the base image own the common post-create setup while the templated shim only passes user-selected dotfiles repo/branch and optional hooks. Relies on the existing base image + setup-dotfiles flow, preserves the read-only host credential mount (no new writable mounts or baked secrets), and calls out required automated checks in template tests to confirm delegation. Documentation updates focus on pointing consumers to the built-in post-create and hook conventions rather than duplicating logic.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Delegate post-create to base image (Priority: P1)

Template maintainers want the generated project post-create hook to stay minimal by delegating to a built-in base image entrypoint while still honoring user-specified dotfiles repo/branch.

**Why this priority**: Reduces per-project boilerplate and drift while keeping user-owned dotfiles and shell choices intact.

**Independent Test**: Apply the template with custom dotfiles repo/branch, create the devcontainer, and verify post-create completes via the base entrypoint without manual edits.

**Acceptance Scenarios**:

1. **Given** a project generated with user-provided dotfiles repo/branch, **When** post-create runs on first container create, **Then** the base entrypoint executes using those values and completes without requiring manual intervention.
2. **Given** the base image is present, **When** the templated post-create shim runs, **Then** it clearly surfaces success or failure from the base entrypoint.

---

### User Story 2 - Add project-specific post-create hook (Priority: P2)

Project owners want to add optional project-specific steps without editing the base logic by providing a hook that runs before or after the base entrypoint.

**Why this priority**: Preserves customizability while preventing divergence from the shared setup.

**Independent Test**: Add an executable hook file, set hook order, and confirm it runs exactly once in the chosen order alongside the base entrypoint.

**Acceptance Scenarios**:

1. **Given** an executable project hook file and a selected order, **When** post-create runs, **Then** the hook executes in that order without skipping the base entrypoint unless explicitly configured to skip.

---

### User Story 3 - Validate template coverage (Priority: P3)

Template testers need automated checks to ensure the shim contains no unresolved placeholders and fails clearly if the base entrypoint is missing.

**Why this priority**: Prevents silent misconfigurations and ensures apply/tests catch regressions early.

**Independent Test**: Run template tests to confirm placeholder replacement, base entrypoint invocation, and failure messaging when the entrypoint is absent.

**Acceptance Scenarios**:

1. **Given** the templated shim after apply, **When** automated checks inspect it, **Then** no template placeholders remain and delegation to the base entrypoint is asserted.

---

### Edge Cases

- What happens when the base post-create entrypoint is not present in the image or not executable?
- How does the system handle a project hook that exits non-zero (e.g., abort vs. continue)?
- What happens when users set skip flags that disable all base steps—does the shim still report success/failure clearly?
- How does the flow behave when git submodules are absent or already initialized?
- How are user-provided dotfiles repo/branch values handled if git remotes are unreachable?

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The generated project post-create script MUST delegate to a base-image post-create entrypoint and pass user-selected dotfiles repo/branch values without requiring manual edits.
- **FR-002**: The base post-create entrypoint MUST perform shared setup steps (dotfiles sync, shell/prompt refresh, git safe-directory, optional submodule init) and honor environment flags to skip individual steps.
- **FR-003**: The system MUST support an optional project-specific post-create hook that can run before or after the base entrypoint based on a single ordering setting, executing exactly once when present.
- **FR-004**: The post-create flow MUST emit a clear, failing status when the base entrypoint is missing, not executable, or returns an error, so users are not left with silent partial setup.
- **FR-005**: Template automation (apply/tests) MUST verify that templated post-create files contain no unresolved placeholders and that delegation to the base entrypoint is exercised in automated checks.

### Key Entities _(include if feature involves data)_

- **Base post-create entrypoint**: Shared routine shipped in the base image that performs common setup tasks and honors per-step skip controls.
- **Project post-create shim**: Lightweight, templated script that injects user dotfiles values, invokes the base entrypoint, and optionally runs a project hook in a defined order.
- **Project hook (optional)**: Consumer-supplied executable invoked by the shim to run project-specific steps either before or after the shared setup.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: 100% of template applications produce a post-create script with zero unresolved placeholders and no required manual edits before first container create.
- **SC-002**: Post-create completes within 60 seconds for default base steps under normal network conditions, with skip flags reducing runtime proportionally when used.
- **SC-003**: 100% of runs with an executable project hook execute the hook exactly once in the configured order without suppressing base setup unless explicitly configured.
- **SC-004**: Automated template checks covering delegation and failure messaging pass in CI with no additional regressions introduced to existing apply or smoke tests.
