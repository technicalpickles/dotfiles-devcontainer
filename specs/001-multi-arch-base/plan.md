# Implementation Plan: Multi-arch base image support

**Branch**: `[001-multi-arch-base]` | **Date**: 2025-12-01 | **Spec**: specs/001-multi-arch-base/spec.md
**Input**: Feature specification from `/specs/001-multi-arch-base/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See the command docs (when present) for the execution workflow.

## Summary

Provide ARM64 and X86/AMD64 base image variants, built on GitHub Actions public runners, with automated smoke/Goss and bats coverage gating releases. Devcontainer builds should auto-select matching architecture from a single base image tag (override available), surface Docker/platform warnings when unsupported, and block releases when any variant fails validation.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Shell scripts (bash), Docker/Buildx on GitHub Actions public runners
**Primary Dependencies**: Docker CLI/buildx, GitHub Actions workflows, bats, Goss
**Storage**: N/A (container images published to registry)
**Testing**: bats test/apply.bats, base-image smoke/Goss for both ARM64 and X86/AMD64
**Target Platform**: GitHub Actions public runners building/publishing to GHCR; devcontainer builds on Apple Silicon and X86/AMD64 hosts
**Project Type**: Devcontainer template/tooling (CLI/scripts)
**Performance Goals**: Base image builds complete within typical GitHub Actions time budget; devcontainer startup on Apple Silicon within 5 minutes (per spec)
**Constraints**: No self-hosted runners; avoid adding tooling already in base image; preserve read-only credential mounts; rely on Docker platform warnings plus apply-script warnings for unsupported platforms
**Scale/Scope**: Two architecture variants (ARM64, X86/AMD64); impacts base image pipeline, apply/build scripts, docs, and tests

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- User-owned environment: No personal defaults; dotfiles repo/branch and shell stay user-specified or explicitly auto-detected with override. Propagation across `devcontainer.json`, `Dockerfile`, and post-create steps confirmed.
- Reproducible base image: Uses `ghcr.io/technicalpickles/dotfiles-devcontainer/base` (pinned digest); avoids adding tooling already in the base image and reuses `setup-dotfiles`.
- Security boundaries: Host credential mounts remain read-only; no new secret storage or privilege escalation beyond `vscode` user without justification.
- Test-first: Plan lists required automated checks (`bats test/apply.bats`, base image smoke/Goss when applicable) before implementation.
- Clarity & DX: Changes document detection behavior, overrides, and macOS performance guidance where relevant; helper scripts remain the primary UX.

## Project Structure

### Documentation (this feature)

```text
specs/001-multi-arch-base/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
```

### Source Code (repository root)

```text
bin/                 # helper scripts (apply/build/run/stop)
docker/              # dockerfiles and build assets
docs/                # user-facing documentation
src/                 # template tooling and helpers
test/                # bats tests and related fixtures
.specify/            # speckit scripts/templates/memory
```

**Structure Decision**: Single repo with scripts, docker assets, docs, and bats tests; changes will touch helper scripts, Docker build workflows, docs, and test suites relevant to base image publishing and devcontainer apply/build flows.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
| -------------------------- | ------------------ | ------------------------------------ |
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |

## Phase 0: Research

- Unknowns/clarifications: None; spec fully specified.
- Research outputs: specs/001-multi-arch-base/research.md
  - Decisions: build/publish dual-arch on GitHub Actions public runners with Buildx; rely on Docker platform warnings plus apply-script warning; block release if any arch fails; users specify only base image tag with optional override.

## Phase 1: Design & Contracts

- Data model: specs/001-multi-arch-base/data-model.md
- Contracts: specs/001-multi-arch-base/contracts/architecture-selection.md (apply/build UX and release pipeline gating)
- Quickstart: specs/001-multi-arch-base/quickstart.md
- Agent context: updated via `.specify/scripts/bash/update-agent-context.sh codex` (see AGENTS.md).

## Constitution Check (post-design)

- User-owned environment: Pass (no personal defaults; auto-detect with override only).
- Reproducible base image: Pass (still pinned base; reuse setup-dotfiles; avoid duplicate tooling).
- Security boundaries: Pass (no new secrets; read-only credential mounts unchanged).
- Test-first: Pass (requires bats/apply and smoke/Goss for both arches; release blocks on failures).
- Clarity & DX: Pass (docs/quickstart and warnings for unsupported platforms; auto-select arch with optional override).

## Phase 2: Implementation Tasks (to be detailed in tasks.md via /speckit.tasks)

- Implement dual-arch build/publish on GitHub Actions public runners with Buildx and manifest push.
- Add/apply-script warning for unsupported architecture detection, leveraging Docker platform warnings.
- Ensure release pipeline blocks when any arch fails smoke/Goss; record per-arch validation.
- Update docs to explain auto-selection, overrides, and warning behavior; keep base image tag-only UX.
- Expand bats/apply and smoke/Goss coverage for both ARM64 and X86/AMD64 flows.
