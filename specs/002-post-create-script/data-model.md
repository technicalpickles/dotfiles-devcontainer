# Data Model: Base Post-Create Entrypoint Shim

## Entities

- **Base post-create entrypoint**
  - Attributes: accepts `DOTFILES_REPO`, `DOTFILES_BRANCH`, skip flags (`SKIP_DOTFILES`, `SKIP_MISE`, `SKIP_FISH`, `SKIP_GH`, `SKIP_AWS`, `SKIP_SUBMODULES`), workspace path, hook path/order; emits logs and exit status.
  - States: `pending` → `running` → `success` or `failure`; submodule step states `skipped|initialized|already-initialized`.

- **Project post-create shim**
  - Attributes: templated values for dotfiles repo/branch, resolves hook path `/workspace/.devcontainer/hooks/post-create`, hook order `before|after` (default `before`), passes through skip flags, captures exit from base entrypoint and hook.
  - States: `pending` → `delegated` → `success` or `failure`; hook invocation `not-present|executed|failed`.

- **Project hook (optional)**
  - Attributes: executable script presence, order (`HOOK_ORDER`), workspace context; produces logs and exit status.
  - States: `absent|present` then `skipped|executed|failed` based on presence and exit code.

## Relationships

- Shim → Base entrypoint: invokes with environment inputs; propagates exit status.
- Shim → Project hook: invokes if executable; order determined by `HOOK_ORDER`.
- Base entrypoint → Submodule handling: runs initialization only when `.gitmodules` exists and submodules uninitialized.
