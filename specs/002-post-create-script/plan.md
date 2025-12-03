# Implementation Plan: Base Post-Create Entrypoint Shim

**Branch**: `002-post-create-script` | **Date**: 2025-12-02 | **Spec**: specs/002-post-create-script/spec.md
**Input**: Feature specification from `/specs/002-post-create-script/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See the command docs (when present) for the execution workflow.

## Summary

Shift common post-create behavior into a base-image entrypoint and ship a slim templated shim that forwards user dotfiles repo/branch and optional hooks. Ensure delegation surfaces clear success/failure, supports skip flags, and is covered by template tests so projects carry minimal boilerplate.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Bash (post-create scripts), devcontainer metadata
**Primary Dependencies**: Base image tooling (`setup-dotfiles`, git, fish/starship already included)
**Storage**: N/A (config files only)
**Testing**: `bats test/apply.bats`, base-image smoke/Goss as applicable
**Target Platform**: Devcontainer on GitHub Actions/public runners and local VS Code (`vscode` user)
**Project Type**: Template tooling (devcontainer)
**Performance Goals**: Post-create completes within 60s for default steps; skips reduce time proportionally
**Constraints**: Read-only host credential mount; reuse base image pinned digest; no extra features beyond base
**Scale/Scope**: Applies to generated projects using this template; no production traffic considerations

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- User-owned environment: No personal defaults; template shim only forwards user-provided dotfiles repo/branch and optional hook. ✅
- Reproducible base image: Delegates to base entrypoint shipped in pinned base image; no duplicated tooling. ✅
- Security boundaries: No new mounts or secrets; honors read-only host credentials; runs as `vscode`. ✅
- Test-first: Add/adjust `bats test/apply.bats` (and smoke/Goss if base image changes) to cover delegation and failure surfacing. ✅
- Clarity & DX: Document delegation, hook location/order, and skip flags in quickstart; keep helper scripts primary. ✅

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
specs/002-post-create-script/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/

src/dotfiles/.devcontainer/post-create.sh   # templated shim source
bin/apply                                   # copies/patches post-create template
test/apply.bats                             # template coverage; add delegation checks
docker/                                     # base image build context for entrypoint inclusion
docs/                                       # README/plan docs updates as needed
```

**Structure Decision**: Single template/tooling project; focus on devcontainer template files, supporting scripts, and tests listed above.

## Phase 0: Outline & Research

- Unknowns: None identified; clarified behavior via decisions below.
- Dependencies/Integrations: Base image entrypoint, templated shim, optional project hook, `setup-dotfiles`.

Research Outcomes (captured in research.md):

- Decision: Ship `/usr/local/bin/devcontainer-post-create` in base image to run shared steps (dotfiles sync, shell/prompt refresh, git safe-directory, optional submodule init). Rationale: centralize boilerplate and keep templates thin. Alternatives: continue templated logic per project (rejected: drift), move all logic into template (rejected: duplication).
- Decision: Shim passes `DOTFILES_REPO/BRANCH` and honors skip flags (`SKIP_DOTFILES`, `SKIP_MISE`, `SKIP_FISH`, `SKIP_GH`, `SKIP_AWS`, `SKIP_SUBMODULES`). Rationale: configurable without edits. Alternatives: hardcoded defaults (rejected: not user-owned), config file (rejected: extra surface).
- Decision: Optional hook at `/workspace/.devcontainer/hooks/post-create` with `HOOK_ORDER` default `before`; always runs exactly once when executable. Rationale: preserves project-specific steps without editing base logic. Alternatives: embed hook paths in shim (rejected: brittle), only after hook (rejected: less flexible).
- Decision: Fail fast if base entrypoint missing/not executable or returns non-zero; propagate exit code. Rationale: avoid silent partial setup. Alternatives: swallow errors (rejected: hides failures).

## Phase 1: Design & Contracts

Data Model (data-model.md):

- Entities: Base post-create entrypoint (inputs: dotfiles repo/branch, skip flags; outputs: status/logs), Project post-create shim (inputs: template values, hook path/order; outputs: base invocation result), Project hook (inputs: workspace context; outputs: success/failure).
- States: Hook order `before|after`; base entrypoint `success|failure`; submodule step `skipped|initialized|already-initialized`.

Contracts (/contracts/):

- CLI contract for `devcontainer-post-create`: expects environment values above, executes shared steps, returns non-zero on failure; emits clear logs when skipping steps. Shim contract: calls base entrypoint, runs hook once in configured order, surfaces failures.

Quickstart (quickstart.md):

- Steps to add base entrypoint, update templated shim to delegate with env/flags, wire optional hook location/order, and extend tests/docs.

Agent Context:

- Updated via `.specify/scripts/bash/update-agent-context.sh codex` after populating plan sections (note upstream warning about duplicate prefix directories; no impact to feature context).

## Phase 2: Implementation Planning (summary for /speckit.tasks)

- Add base entrypoint script to base image build context with skip flags and hook invocation support.
- Refactor templated `src/dotfiles/.devcontainer/post-create.sh` to shim mode, passing template values and hook order/env.
- Update `bin/apply` placeholder replacement if needed and extend `test/apply.bats` to assert delegation, no placeholders, and missing-entrypoint failure messaging; add/adjust base smoke tests if base image changes.
- Update docs (README/quickstart) to describe delegation, hook path, skip flags, and error behavior.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
| -------------------------- | ------------------ | ------------------------------------ |
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |
