# Research: Base Post-Create Entrypoint Shim

## Decisions

- **Base entrypoint location and scope**
  - Decision: Provide `/usr/local/bin/devcontainer-post-create` in the base image to run shared steps (dotfiles sync via `setup-dotfiles`, shell/prompt refresh, git safe-directory, optional submodule init).
  - Rationale: Centralizes boilerplate and keeps generated projects minimal; leverages base image tooling already present.
  - Alternatives: Keep full logic in templated post-create (rejected: duplication and drift); push logic into per-project hooks (rejected: inconsistent behavior).

- **Configuration surface (env flags and dotfiles inputs)**
  - Decision: Shim exports `DOTFILES_REPO/BRANCH` from template values and honors skip flags (`SKIP_DOTFILES`, `SKIP_MISE`, `SKIP_FISH`, `SKIP_GH`, `SKIP_AWS`, `SKIP_SUBMODULES`).
  - Rationale: Allows opt-out without editing scripts; keeps user-owned dotfiles choices intact.
  - Alternatives: Hardcoded defaults (rejected: violates user-owned environment), config files (rejected: extra state surface).

- **Project hook integration**
  - Decision: Support optional executable hook at `/workspace/.devcontainer/hooks/post-create` with `HOOK_ORDER` default `before`; run exactly once when present.
  - Rationale: Enables project-specific steps without altering base logic; ordering covers before/after needs.
  - Alternatives: Only after-hook (rejected: less flexible), embedding hook commands in shim (rejected: brittle).

- **Error handling and visibility**
  - Decision: Fail fast when base entrypoint is missing/not executable or returns non-zero; propagate exit code and emit clear logs.
  - Rationale: Prevents silent partial setup and surfaces issues early in apply/tests.
  - Alternatives: Swallow errors (rejected: hides failures), best-effort mode (rejected: unpredictable state).
