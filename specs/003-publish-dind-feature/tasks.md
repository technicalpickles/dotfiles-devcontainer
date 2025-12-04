---
description: "Task list for Publish DinD Feature for Dotfiles Devcontainer"
---

# Tasks: Publish DinD Feature for Dotfiles Devcontainer

**Input**: Design documents from `/specs/003-publish-dind-feature/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Include/extend automated checks for template + base image changes (`devcontainer features publish` package/tests, `bats test/apply.bats`, base-image smoke/Goss). Respect security boundaries (host mounts like `~/.aws` stay read-only). Performance tolerance: devcontainer builds within +10% or +30s (whichever is greater) of baseline on GHA public runners.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project scaffolding and documentation prep

- [ ] T001 Create published-feature tracking skeleton with sections for versions/digests, base image digest, performance baseline, and outage notes in `docs/dind-feature.md`
- [ ] T002 Add performance baseline capture steps (apply/build timing + Docker verification) to `specs/003-publish-dind-feature/quickstart.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core alignment required before any user story work

- [ ] T003 Record pinned base image digest and `setup-dotfiles` context comments to enforce determinism in `src/dotfiles/.devcontainer/devcontainer.json`
- [ ] T004 [P] Extend `docker/goss.yaml` with Docker engine/CLI expectations that match DinD wiring to guard against base-image drift
- [ ] T005 [P] Make `test/features/dind/test.sh` accept configurable feature version/digest inputs for publish validation runs

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Consume published DinD feature (Priority: P1) 🎯 MVP

**Goal**: Template consumes the published DinD feature by reference; no feature files are copied into consuming repos while Docker remains functional.

**Independent Test**: Apply template to a clean repo, build the devcontainer, and verify Docker works without a `.devcontainer/features` folder being added.

### Implementation for User Story 1

- [ ] T006 [US1] Update features block to reference GHCR DinD latest released tag on creation (no vendored assets) in `src/dotfiles/.devcontainer/devcontainer.json`
- [ ] T007 [P] [US1] Adjust templating to exclude `src/dotfiles/.devcontainer/features/` when applying the template in `bin/apply`
- [ ] T008 [US1] Extend `test/apply.bats` to assert applied repos lack `.devcontainer/features` and Docker commands succeed using the prebaked base image
- [ ] T009 [P] [US1] Document default remote feature usage and verification steps in `specs/003-publish-dind-feature/quickstart.md`

**Checkpoint**: User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Publish and version the feature (Priority: P2)

**Goal**: Maintainers can publish/version the DinD feature to GHCR with clear versioning and template reference updates.

**Independent Test**: Run the publish flow and verify GHCR shows the new version/digest; template reference updates accordingly; validation steps pass.

### Implementation for User Story 2

- [ ] T010 [US2] Update `src/dotfiles/.devcontainer/features/dind/devcontainer-feature.json` with semver version metadata, GHCR registry path, and privileged wiring flags aligned to the base image
- [ ] T011 [P] [US2] Align `src/dotfiles/.devcontainer/features/dind/install.sh` to rely on base image Docker bits and expose required env/mount defaults
- [ ] T012 [US2] Enhance `bin/publish-dind-feature` to run `devcontainer features publish` with version input, packaging/tests, and emit version + digest output
- [ ] T013 [US2] Add `.github/workflows/publish-dind-feature.yml` to package/publish with bats + Goss validation against the pinned base image digest
- [ ] T014 [P] [US2] Update `test/features/dind/test.sh` to assert publish output includes registry path, semver tag, digest, and privileged wiring expectations
- [ ] T015 [US2] Record published version/digest and validation results in `docs/dind-feature.md` and update the template reference accordingly in `src/dotfiles/.devcontainer/devcontainer.json`

**Checkpoint**: User Story 2 should be fully functional and testable independently

---

## Phase 5: User Story 3 - Pin and recover from registry issues (Priority: P3)

**Goal**: Consumers can pin specific feature versions/digests and follow fallback guidance during registry outages.

**Independent Test**: Configure the template with a pinned version/digest, simulate a registry fetch failure, and verify documented fallback steps enable continuation/retry.

### Implementation for User Story 3

- [ ] T016 [US3] Add digest pin example and deterministic-build comment to the features block for CI/release flows in `src/dotfiles/.devcontainer/devcontainer.json`
- [ ] T017 [P] [US3] Add digest resolution + pin helper workflow for CI/release in `.github/workflows/pin-dind-feature.yml`
- [ ] T018 [US3] Document retry/backoff, pinned digest, and temporary vendor fallback steps (with cleanup reminder) in `docs/dind-feature.md`
- [ ] T019 [P] [US3] Add fallback test scenario covering pinned digest or simulated registry failure to `test/apply.bats`

**Checkpoint**: User Story 3 should be fully functional and testable independently

---

## Phase N: Polish & Cross-Cutting Concerns

- [ ] T020 [P] Capture apply/build timing on a GHA run using `bin/apply` + `bin/build` and record baseline delta (within +10% or +30s) in `specs/003-publish-dind-feature/quickstart.md`
- [ ] T021 Harden privileged + credential boundary notes (host `~/.aws` read-only, DinD requires privileged) in `docs/dind-feature.md`
- [ ] T022 [P] Add release note entry for the latest published version/digest and pinning guidance in `docs/releases/dind-feature.md`

---

## Dependencies & Execution Order

- Setup (Phase 1) → Foundational (Phase 2) → User Stories (Phase 3 P1 → Phase 4 P2 → Phase 5 P3) → Polish.
- Foundational tasks block all user stories; each story remains independently testable once its phase completes.
- Template updates that rely on publish outputs (T015) depend on publish completion (T012–T014).

## Parallel Opportunities

- T001 and T002 can run in parallel.
- After foundational tasks, US1 tasks T007–T009 can run in parallel once T006 sets the reference expectation.
- For US2, T011 and T014 can run in parallel after T010; T012 and T013 can proceed together; T015 follows publish outputs.
- For US3, T017 and T019 can proceed in parallel after T016; T018 is documentation-only and parallel-safe.
- Polish tasks T020 and T022 are parallel-safe; T021 can run independently once docs exist.

## Parallel Execution Examples

- **US1**: Run T007 and T009 concurrently while another contributor updates tests in T008.
- **US2**: Execute publish automation (T012, T013) while wiring validation expectations in T014.
- **US3**: Implement CI digest pinning (T017) while drafting outage guidance/tests (T018, T019).

## Implementation Strategy

- MVP first: Complete Setup + Foundational, then deliver US1 end-to-end (template reference, exclusion from apply, tests, docs).
- Incremental: Add US2 publish/version automation next, then US3 pin/fallback. Validate after each story using the independent tests and recorded evidence before moving to Polish.
