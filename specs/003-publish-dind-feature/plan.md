# Implementation Plan: Publish DinD Feature for Dotfiles Devcontainer

**Branch**: `003-publish-dind-feature` | **Date**: 2025-12-02 | **Spec**: /Users/josh.nichols/workspace/pickled-devcontainer/specs/003-publish-dind-feature/spec.md
**Input**: Feature specification from `/specs/003-publish-dind-feature/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See the command docs (when present) for the execution workflow.

## Summary

Publish the Docker-in-Docker feature to GHCR and default the template to consume the latest released feature tag (with baked Docker engine in the base image), then pin the resolved digest in CI/release for deterministic builds. Keep consuming repos free of vendored feature assets while preserving Docker functionality and outage fallback guidance.

## Technical Context

**Language/Version**: Bash scripting; YAML (devcontainer feature metadata, GitHub Actions)
**Primary Dependencies**: Devcontainer CLI (features package/publish), Docker/Buildx (via base image and GH Actions), GHCR registry, bats, Goss/base smoke
**Storage**: N/A (registry-hosted feature artifacts)
**Testing**: `devcontainer features publish` packaging/tests, `bats test/apply.bats`, base-image Goss smoke aligned to pinned digest
**Target Platform**: VS Code / Codespaces devcontainers on Linux with privileged DinD support
**Project Type**: Devcontainer template + published feature assets
**Performance Goals**: Devcontainer builds within +10% or +30s (whichever greater) of current baseline on GHA public runners; avoid duplicate Docker engine downloads
**Constraints**: Pinned base image digest; reuse `setup-dotfiles`; no new secrets or writable host mounts; DinD requires privileged containers; GHCR publish via public runners
**Scale/Scope**: Template consumed across downstream repos; feature versioning must support pinning and updates without repo-local feature copies

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
specs/003-publish-dind-feature/
├── plan.md              # This file (/speckit.plan output)
├── research.md          # Phase 0 output (/speckit.plan)
├── data-model.md        # Phase 1 output (/speckit.plan)
├── quickstart.md        # Phase 1 output (/speckit.plan)
├── contracts/           # Phase 1 output (/speckit.plan)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
src/
└── dotfiles/
    └── .devcontainer/
        ├── devcontainer.json
        └── features/
            └── dind/
                ├── devcontainer-feature.json
                └── install.sh

docker/
├── base/
└── goss.yaml

test/
├── apply.bats
├── fixtures/
├── dotfiles/
├── test-utils/
└── features/
    └── dind/
        └── test.sh

bin/
├── apply
├── build
├── publish-dind-feature
├── run
└── stop
```

**Structure Decision**: Devcontainer template assets under `src/dotfiles/.devcontainer`; DinD feature source under `features/dind`; Docker base image + Goss under `docker/`; tests under `test/`; helper scripts under `bin/`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --------- | ---------- | ------------------------------------ |
| None      | N/A        | N/A                                  |

## Phase 0: Research

- Unknowns/clarifications: Resolved performance tolerance (+10% or +30s) and default template behavior (latest released DinD tag at creation, digest pin in CI/release).
- Research outputs: specs/003-publish-dind-feature/research.md
  - Decisions: Publish via `devcontainer features publish` to GHCR under devcontainer-features namespace; semver with digest pins; template consumes by reference (no vendoring); fallback steps for registry outages; validation includes feature packaging/tests, `bats test/apply.bats`, and base-image Goss alignment for Docker bits.
  - Tradeoffs: Avoid floating `latest` in CI/release; keep feature wiring lean (no Docker engine duplication); privileged DinD required.

## Phase 1: Design & Contracts

- Data model: specs/003-publish-dind-feature/data-model.md
- Contracts: specs/003-publish-dind-feature/contracts/dind-feature.openapi.yaml (publish, list versions, update template reference, fallback guidance)
- Quickstart: specs/003-publish-dind-feature/quickstart.md
- Agent context: updated via `.specify/scripts/bash/update-agent-context.sh codex` (see AGENTS.md).

## Constitution Check (post-design)

- User-owned environment: Pass (no personal defaults; template defaults to DinD feature wiring without altering dotfiles/shell propagation).
- Reproducible base image: Pass (base image remains pinned; feature wiring relies on baked Docker bits; reuse `setup-dotfiles`).
- Security boundaries: Pass (no new secrets; host credential mounts unchanged; privileged use remains scoped to Docker-in-Docker needs).
- Test-first: Pass (plan includes `devcontainer features publish` validation, `bats test/apply.bats`, and base-image Goss alignment).
- Clarity & DX: Pass (quickstart + fallback guidance; template reference keeps repos clean; helper scripts remain primary UX).

## Phase 2: Implementation Planning (summary for /speckit.tasks)

- Implement GHCR publish workflow for the DinD feature using `devcontainer features publish` with semver tags and recorded digests.
- Update `src/dotfiles/.devcontainer/devcontainer.json` to consume the published feature by reference (default to latest released tag on template creation; pin digest in CI/release; no vendored feature files).
- Add/update CI to validate publishes and template consumption (`bats test/apply.bats`; base-image Goss covers Docker bits alignment; security boundary check for read-only host mounts).
- Document pinning/updating, performance tolerance, and outage fallback (retry, digest pin, temporary vendor with cleanup) alongside release notes.
