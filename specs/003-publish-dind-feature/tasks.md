# Tasks: Publish DinD Feature for Dotfiles Devcontainer

**Input**: Design documents from `/specs/003-publish-dind-feature/`
**Prerequisites**: plan.md (required), spec.md (user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Template/base image changes MUST include or extend automated checks (`bats test/apply.bats`, base-image smoke/Goss). Include feature packaging validation when publishing.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare feature source and documentation scaffolding

- [ ] T001 Create DinD feature scaffold (`devcontainer-feature.json`, `install.sh`) in `src/dotfiles/.devcontainer/features/dind/`
- [ ] T002 [P] Add DinD feature release notes + version/digest tracking stub in `docs/dind-feature.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core feature wiring and tooling required before user stories

- [ ] T003 Implement Docker-in-Docker wiring (privileged, mounts, env, entrypoint) aligned to base Docker bits in `src/dotfiles/.devcontainer/features/dind/`
- [ ] T004 Add publish helper script wrapping `devcontainer features package/publish` with GHCR defaults and validation in `bin/publish-dind-feature`
- [ ] T005 Add feature validation harness (e.g., `devcontainer features test` or equivalent checks) for DinD in `test/features/dind/test.sh`

**Checkpoint**: Foundation ready - user story implementation can begin

---

## Phase 3: User Story 1 - Consume published DinD feature (Priority: P1) 🎯 MVP

**Goal**: Template consumes the published DinD feature by reference; no feature files are copied into consuming repos while Docker remains functional.

**Independent Test**: Apply template to a clean repo, build devcontainer, confirm Docker works and no `.devcontainer/features` folder is added locally.

### Implementation for User Story 1

- [ ] T006 [US1] Update devcontainer feature reference to GHCR DinD version/digest in `src/dotfiles/.devcontainer/devcontainer.json` (remove reliance on built-in docker-in-docker feature)
- [ ] T007 [P] [US1] Add BATS coverage in `test/apply.bats` to assert GHCR DinD feature reference is pinned and no `.devcontainer/features` directory is created
- [ ] T008 [P] [US1] Document consumer usage (pin/update, expected Docker availability) for the published feature in `README.md`

**Checkpoint**: User Story 1 functional and testable independently

---

## Phase 4: User Story 2 - Publish and version the feature (Priority: P2)

**Goal**: Maintainers can publish/version the DinD feature to GHCR with clear versioning and template reference updates.

**Independent Test**: Run publish flow and verify GHCR shows the new version/digest; template reference updated to the published version.

### Implementation for User Story 2

- [ ] T009 [US2] Add GHCR publish workflow using `devcontainer features publish` with package/test steps and digest summary in `.github/workflows/feature-publish.yaml`
- [ ] T010 [P] [US2] Wire `bin/publish-dind-feature` inputs/validation to support CI and local publishes for `src/dotfiles/.devcontainer/features/dind/`
- [ ] T011 [US2] Document maintainer publish + template-update steps (semver vs digest pins) in `docs/ci.md`
- [ ] T012 [P] [US2] Record published version/digest entry and align template reference after publish in `docs/dind-feature.md` and `src/dotfiles/.devcontainer/devcontainer.json`

**Checkpoint**: User Story 2 functional and testable independently

---

## Phase 5: User Story 3 - Pin and recover from registry issues (Priority: P3)

**Goal**: Consumers can pin specific feature versions/digests and follow fallback guidance during registry outages.

**Independent Test**: Configure template with pinned version/digest, simulate registry fetch failure, and verify documented fallback steps enable continuation/retry.

### Implementation for User Story 3

- [ ] T013 [US3] Document pin/digest fallback steps and outage recovery guidance in `docs/dind-feature.md` and `specs/003-publish-dind-feature/quickstart.md`
- [ ] T014 [US3] Annotate features block with pinned version/digest guidance in `src/dotfiles/.devcontainer/devcontainer.json`
- [ ] T015 [P] [US3] Add troubleshooting/rollback notes for registry outages in `README.md` (linking to pin/digest guidance)

**Checkpoint**: User Story 3 functional and testable independently

---

## Phase N: Polish & Cross-Cutting Concerns

- [ ] T016 [P] Run DinD feature validation + `bats test/apply.bats` and record results/versions in `docs/dind-feature.md`
- [ ] T017 Align quickstart and maintainer docs after implementation (cross-check `quickstart.md`, `README.md`, `docs/ci.md`, `docs/dind-feature.md`)

---

## Dependencies & Execution Order

- Setup (Phase 1) → Foundational (Phase 2) → User Stories (Phase 3 P1 → Phase 4 P2 → Phase 5 P3) → Polish.
- User stories remain independently testable once foundational work is complete; prioritize P1 → P2 → P3.
- Tests in each story should be runnable immediately after that story’s tasks without waiting for later stories.

## Parallel Opportunities

- T001 and T002 can run in parallel.
- Within US1, T007 (tests) and T008 (docs) can proceed in parallel once T006 defines the expected feature reference.
- Within US2, T010 (script wiring) and T012 (version/digest recording) can run in parallel after T009 establishes the workflow.
- Within US3, T013 and T015 are parallel documentation tasks after T014 defines the annotated reference.

## Implementation Strategy

- MVP: Complete Setup + Foundational, then deliver User Story 1 end-to-end (feature reference updated, tests/docs) before proceeding.
- Incremental: Ship US1 (consumption), then US2 (publish/version), then US3 (pin/fallback), validating after each phase via story-specific independent tests.
