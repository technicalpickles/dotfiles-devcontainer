---
description: "Task list for Base Post-Create Entrypoint Shim"
---

# Tasks: Base Post-Create Entrypoint Shim

**Input**: Design documents from `/specs/002-post-create-script/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Template/base image changes MUST include or extend automated checks (`bats test/apply.bats`, base-image smoke/Goss). Tests are included where they guard delegation and failure surfacing.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare base image context for shared post-create entrypoint

- [x] T001 Create base post-create entrypoint file scaffold in `docker/base/devcontainer-post-create`
- [x] T002 Update `docker/base/Dockerfile` to install `devcontainer-post-create` into `/usr/local/bin` with executable permissions

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Baseline coverage and wiring required before user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Add base image presence check for `devcontainer-post-create` in `docker/goss.yaml` (or equivalent smoke test) to fail if missing
- [x] T004 Refresh agent context note in `AGENTS.md` to reflect 002 feature path and base entrypoint addition

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Delegate post-create to base image (Priority: P1) 🎯 MVP

**Goal**: Generated post-create shim delegates to base-image entrypoint using user dotfiles repo/branch and surfaces success/failure clearly

**Independent Test**: Apply template with custom dotfiles repo/branch, run devcontainer create, and verify base entrypoint runs and reports status without manual edits

### Implementation for User Story 1

- [x] T005 [US1] Implement shared steps and skip-flag handling in `docker/base/devcontainer-post-create` (dotfiles sync, shell/prompt refresh, git safe-directory, submodule guard)
- [x] T006 [US1] Refactor `src/dotfiles/.devcontainer/post-create.sh` to export templated `DOTFILES_REPO/BRANCH`, invoke `devcontainer-post-create`, and propagate failures
- [x] T007 [US1] Ensure `bin/apply` replaces dotfiles placeholders and preserves shim delegation paths for post-create
- [x] T008 [US1] Document base entrypoint delegation and skip flags in `docs/README.md` (or nearest devcontainer usage doc)

**Checkpoint**: User Story 1 functional and independently testable

---

## Phase 4: User Story 2 - Add project-specific post-create hook (Priority: P2)

**Goal**: Allow optional project hook to run before or after the base entrypoint without altering shared logic

**Independent Test**: Add an executable hook at `/workspace/.devcontainer/hooks/post-create`, set `HOOK_ORDER`, and confirm it runs exactly once in the configured order alongside base setup

### Implementation for User Story 2

- [x] T009 [US2] Extend `src/dotfiles/.devcontainer/post-create.sh` to execute hook at `/workspace/.devcontainer/hooks/post-create` respecting `HOOK_ORDER=before|after`
- [x] T010 [US2] Wire hook invocation handling (order + single execution) into `docker/base/devcontainer-post-create` with clear logging of skipped/ran status
- [x] T011 [US2] Add hook usage and ordering guidance to `docs/README.md` (or dedicated devcontainer doc section)

**Checkpoint**: User Story 2 functional and independently testable

---

## Phase 5: User Story 3 - Validate template coverage (Priority: P3)

**Goal**: Automated checks ensure delegation, placeholder cleanup, and clear failure messaging when base entrypoint is absent

**Independent Test**: Run template tests; they fail when placeholders remain or when base entrypoint is missing/unreachable, and pass when delegation works

### Implementation for User Story 3

- [x] T012 [US3] Extend `test/apply.bats` to assert no template placeholders remain in `.devcontainer/post-create.sh` after apply and that the shim calls the base entrypoint
- [x] T013 [US3] Add bats coverage for missing/non-executable `devcontainer-post-create` to ensure clear failing status and message
- [x] T014 [US3] Expand `docker/goss.yaml` (or equivalent smoke) to verify hook path expectations and executable permissions for `devcontainer-post-create`

**Checkpoint**: All user stories independently testable with automated coverage

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Repo-wide refinements after core stories

- [x] T015 [P] Align `specs/002-post-create-script/quickstart.md` and `doc`/`README` references to final behavior and env flags
- [x] T016 [P] Code cleanup and formatting passes on `docker/base/devcontainer-post-create` and `src/dotfiles/.devcontainer/post-create.sh`
- [x] T017 [P] Run end-to-end quickstart validation following `specs/002-post-create-script/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (Phase 1): No dependencies - can start immediately
- Foundational (Phase 2): Depends on Setup completion - BLOCKS all user stories
- User Stories (Phase 3+): All depend on Foundational phase completion; proceed in priority order (P1 → P2 → P3) or in parallel once foundation is ready
- Polish (Final Phase): Depends on all desired user stories being complete

### User Story Dependencies

- User Story 1 (P1): Starts after Foundational; no other story dependencies
- User Story 2 (P2): Starts after Foundational; can run after or alongside US1 once shared hook wiring is ready
- User Story 3 (P3): Starts after Foundational; can run after US1 to reuse delegation behaviors, parallel to US2

### Within Each User Story

- Models/logic before docs/tests that validate them (tests for US3 can follow shim/entrypoint wiring from US1/US2)
- Hook handling (US2) depends on base entrypoint presence (US1 foundation)
- Tests (US3) depend on implemented behaviors from US1/US2

### Parallel Opportunities

- Setup tasks (T001-T002) can run concurrently if paths do not conflict
- Foundational tasks (T003-T004) can run in parallel
- After foundation: docs (T008, T011) can progress in parallel with implementation tasks that touch different files; tests (T012-T014) can run after core behaviors exist
- Polish tasks (T015-T017) can run in parallel once core stories are done

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run apply + devcontainer create to confirm delegation and skip flags work
5. Demo/document if ready

### Incremental Delivery

1. Setup + Foundational → foundation ready
2. Add User Story 1 → test independently → demo (MVP)
3. Add User Story 2 → test hook ordering → demo
4. Add User Story 3 → ensure automated checks cover delegation/failure

### Parallel Team Strategy

1. Team completes Setup + Foundational together
2. Once foundation is ready:
   - Developer A: US1 (entrypoint + shim wiring)
   - Developer B: US2 (hook ordering + docs)
   - Developer C: US3 (tests/smoke enhancements)
3. Reconvene for polish and quickstart validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing the behavior they cover
- Commit after each task or logical group
- Avoid overlapping edits to `docker/base/devcontainer-post-create` when parallelizing
