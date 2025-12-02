# Tasks: Multi-arch base image support

## Phase 1: Setup

- [x] T001 Create tasks scaffold for feature docs in specs/001-multi-arch-base/
- [x] T002 Verify GitHub Actions runners support Docker Buildx for dual-arch builds (docs/ci.md)
- [x] T003 Confirm registry credentials for GHCR publishing are configured in GitHub Actions secrets (docs/ci.md)

## Phase 2: Foundational

- [x] T004 Ensure base image Docker build context supports Buildx multi-arch (docker/; adjust Dockerfile if needed)
- [x] T005 Add/verify Buildx invocation for ARM64 and X86/AMD64 in release workflow (e.g., .github/workflows/\*)
- [x] T006 Add per-architecture smoke/Goss test steps in release pipeline (e.g., .github/workflows/\*)
- [x] T007 Ensure bats test/apply.bats covers architecture auto-selection warnings (test/apply.bats)
- [x] T008 Document architecture auto-selection and override behavior (docs/README.md or docs/architecture.md)

## Phase 3: User Story 1 (P1) - Apple Silicon devcontainer build works natively

- [x] T009 [US1] Implement architecture detection and selection logic to default to ARM64 on Apple Silicon (bin/apply or src scripts)
- [x] T010 [US1] Add apply-script warning when detected platform is unsupported, leveraging Docker platform warnings (bin/apply or src scripts)
- [x] T011 [US1] Validate ARM64 base image tagging/discovery in build outputs (docker/ or release metadata)
- [x] T012 [US1] Update quickstart/docs with Apple Silicon flow and expected warnings (docs/README.md; specs/001-multi-arch-base/quickstart.md)
- [x] T013 [US1] Expand bats coverage for Apple Silicon auto-selection and warning paths (test/apply.bats)

## Phase 4: User Story 2 (P2) - Release maintainers publish both architectures

- [x] T014 [US2] Implement dual-arch Buildx job in GitHub Actions with manifest push to GHCR ( .github/workflows/\* )
- [x] T015 [US2] Add per-arch smoke/Goss runs gating publication; fail release if any arch fails ( .github/workflows/\* )
- [x] T016 [US2] Record release artifact metadata per arch (tag, digest, validation status) (release notes or docs/ci.md)
- [x] T017 [US2] Document release steps and failure handling for arch-specific failures (docs/ci.md)

## Phase 5: User Story 3 (P3) - Intel users remain unaffected

- [x] T018 [US3] Confirm auto-selection resolves to X86/AMD64 on Intel hosts without extra steps (bin/apply or test)
- [x] T019 [US3] Ensure no regressions in existing X86/AMD64 devcontainer build path (bats or smoke tests) (test/apply.bats; docker/)
- [x] T020 [US3] Update docs to affirm unchanged Intel workflow and tag-only usage (docs/README.md)

## Phase 6: Polish & Cross-Cutting

- [x] T021 Add/tag architecture metadata in release outputs for discoverability (docs/release-notes.md or artifacts)
- [x] T022 Review logging/messages for clarity on platform selection and warnings (bin/apply; docs)
- [x] T023 Final documentation sweep for auto-select/override and troubleshooting (docs/README.md; docs/ci.md)
- [x] T024 Final test sweep: bats/apply and smoke/Goss for both arches (test/apply.bats; docker/tests)

## Dependencies (story order)

- US1 → US2 → US3

## Parallel Execution Examples

- Build pipeline tasks (T014, T015) can run in parallel with doc updates (T017, T020) once foundational Buildx support (T005) exists.
- Warning/UX work (T010, T022) can proceed alongside release metadata tasks (T016) after architecture detection (T009) is ready.
- Intel regression checks (T018, T019) can run in parallel with Apple Silicon docs (T012) once auto-selection is implemented.

## Implementation Strategy

- MVP: Complete US1 (T009–T013) to deliver native Apple Silicon builds with warnings and tests.
- Incremental: Add US2 release gating next, then verify US3 to confirm no regressions; finish with polish and cross-cutting tasks.
