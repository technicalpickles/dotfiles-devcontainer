# Contract: Post-Create Delegation Interface

## CLI: `devcontainer-post-create` (base image)

- Inputs (env):
  - `DOTFILES_REPO`, `DOTFILES_BRANCH`: source for `setup-dotfiles`.
  - Skip flags: `SKIP_DOTFILES`, `SKIP_MISE`, `SKIP_FISH`, `SKIP_GH`, `SKIP_AWS`, `SKIP_SUBMODULES` (`1` to skip).
  - Hook path/order: optional `HOOK_ORDER` (`before|after`), hook at `/workspace/.devcontainer/hooks/post-create`.
- Behavior:
  - Runs shared steps; only executes submodule init when `.gitmodules` exists and submodules are uninitialized.
  - Invokes hook once if executable and present in configured order.
  - Emits clear logs for executed and skipped steps.
- Outputs:
  - Exit code `0` on success; non-zero on any failed step or missing base entrypoint requirements.

## Shim: `.devcontainer/post-create.sh` (templated)

- Inputs:
  - Templated `DOTFILES_REPO/BRANCH` from apply time; pass-through of skip flags and `HOOK_ORDER`.
  - Optional hook at `/workspace/.devcontainer/hooks/post-create`.
- Behavior:
  - Exports dotfiles values, runs hook if `HOOK_ORDER=before`, calls `devcontainer-post-create`, then runs hook if `HOOK_ORDER=after`.
  - Fails fast if base entrypoint is missing/not executable; propagates base exit codes.
- Outputs:
  - Exit code mirrors base entrypoint or hook failure; emits actionable error when base entrypoint is absent.
