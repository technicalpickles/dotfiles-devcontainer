# Implementation Plan: Publish DinD Feature for Dotfiles Devcontainer

**Branch**: `003-publish-dind-feature` | **Date**: 2025-12-02 | **Spec**: /Users/josh.nichols/workspace/pickled-devcontainer/specs/003-publish-dind-feature/spec.md
**Input**: Feature specification from `/specs/003-publish-dind-feature/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See the command docs (when present) for the execution workflow.

## Summary

Publish the Docker-in-Docker feature to the registry namespace and reference it from the devcontainer template so consuming repos avoid copying feature assets while retaining Docker functionality. Use the existing base image (with baked Docker bits) and align the feature’s wiring and version pinning with template references and documentation.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Bash scripting, YAML (devcontainer feature metadata, GitHub Actions) on Linux containers
**Primary Dependencies**: Devcontainer feature spec, Docker/Buildx CLI (via base image), GHCR registry for publishing, GitHub Actions CI, bats for template tests, Goss for base image smoke
**Storage**: N/A (registry storage for published feature artifacts)
**Testing**: `bats test/apply.bats`, base image smoke/Goss tests, feature publish validation workflow
**Target Platform**: VS Code / Codespaces devcontainers running on Linux with privileged Docker-in-Docker support
**Project Type**: Devcontainer template + published feature assets
**Performance Goals**: Keep devcontainer build time minimized by pulling published feature and reusing baked Docker bits; avoid redundant downloads
**Constraints**: Must use pinned base image digest and `setup-dotfiles`; no embedded secrets; host `~/.aws` mount stays read-only; feature must align with prebaked Docker components; publish process must be repeatable on GitHub Actions public runners
**Scale/Scope**: Template consumed across downstream repos; feature versioning must support pinning and updates without repo-local feature copies

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- Status PASS — User-owned environment: No personal defaults; dotfiles repo/branch and shell stay user-specified or explicitly auto-detected with override. Propagation across `devcontainer.json`, `Dockerfile`, and post-create steps confirmed.
- Status PASS — Reproducible base image: Uses `ghcr.io/technicalpickles/dotfiles-devcontainer/base` (pinned digest); avoids adding tooling already in the base image and reuses `setup-dotfiles`.
- Status PASS — Security boundaries: Host credential mounts remain read-only; no new secret storage or privilege escalation beyond `vscode` user without justification.
- Status PASS — Test-first: Plan lists required automated checks (`bats test/apply.bats`, base image smoke/Goss when applicable) before implementation.
- Status PASS — Clarity & DX: Changes document detection behavior, overrides, and macOS performance guidance where relevant; helper scripts remain the primary UX.

## Project Structure

### Documentation (this feature)

```text
specs/003-publish-dind-feature/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
```

### Source Code (repository root)

```text
src/
└── dotfiles/
    └── devcontainer-template.json

docker/
├── base/
└── goss.yaml

test/
├── apply.bats
├── fixtures/
├── dotfiles/
└── test-utils/

bin/
├── apply
├── build
├── run
└── stop
```

**Structure Decision**: Devcontainer template assets live under `src/dotfiles`; supporting scripts under `bin/`; Docker base image and validation assets under `docker/`; template and feature tests under `test/`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --------- | ---------- | ------------------------------------ |
| None      | N/A        | N/A                                  |

## Phase 0: Research

- Unknowns/clarifications: None flagged; research focused on publish flow, versioning, and outage fallback.
- Research outputs: specs/003-publish-dind-feature/research.md
  - Decisions: publish via `devcontainer features publish` to GHCR under the devcontainer-features namespace; use semver with optional digest pins; template consumes by reference (no vendoring); fallback steps documented for registry outages; validation includes feature packaging, `bats test/apply.bats`, and base-image Goss alignment for Docker bits.

## Phase 1: Design & Contracts

- Data model: specs/003-publish-dind-feature/data-model.md
- Contracts: specs/003-publish-dind-feature/contracts/dind-feature.openapi.yaml (publish, list versions, update template reference, fallback guidance)
- Quickstart: specs/003-publish-dind-feature/quickstart.md
- Agent context: updated via `.specify/scripts/bash/update-agent-context.sh codex` (see AGENTS.md).

## Constitution Check (post-design)

- User-owned environment: Pass (no personal defaults; feature reference does not alter dotfiles/shell propagation).
- Reproducible base image: Pass (base image remains pinned; feature wiring relies on baked Docker bits; reuse `setup-dotfiles`).
- Security boundaries: Pass (no new secrets; host credential mounts unchanged; privileged use remains scoped to Docker-in-Docker needs).
- Test-first: Pass (plan includes `devcontainer features publish` validation, `bats test/apply.bats`, and base-image Goss alignment).
- Clarity & DX: Pass (quickstart + fallback guidance; template reference keeps repos clean; helper scripts remain primary UX).

## Phase 2: Implementation Planning (summary for /speckit.tasks)

- Implement GHCR publish workflow for the DinD feature using `devcontainer features publish` with semver tags and recorded digests.
- Update `devcontainer-template.json` to consume the published feature by reference (no vendored feature files) with version/digest pin.
- Add/update CI to validate publishes and template consumption (`bats test/apply.bats`; ensure base-image Goss covers Docker bits alignment).
- Document pinning/updating and outage fallback (retry, digest pin, temporary vendor with cleanup) alongside release notes.
