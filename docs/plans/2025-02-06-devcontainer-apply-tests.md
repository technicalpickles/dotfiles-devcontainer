# Devcontainer Apply Smoke Tests

## Goal

Codify a fast, repeatable check that the template stays generic (no hardcoded personal dotfiles) and that shell overrides propagate everywhere when using `bin/apply` or the published template.

## Scope

- Template application via `bin/apply` when run from the repo (file-copy path).
- Detection that all `${templateOption:...}` placeholders are replaced.
- Propagation of dotfiles repo/branch and shell settings into `devcontainer.json`, `Dockerfile`, and `post-create.sh`.
- Shell/profile overrides via env vars (and implicitly CLI flags, since they write the same envs).

## Dependencies

- `bats` ([bats-core/bats-core](https://github.com/bats-core/bats-core))
- `rg` (ripgrep)
- `jq`

## Test Command

From repo root, after installing bats (e.g., `npm i -g bats` or `brew install bats-core`), run:

```bash
bats test/apply.bats
```

## Test Cases (planned in `test/apply.bats`)

1. **Default templating is generic**
   - Run `./bin/apply ci-unpinned` into a temp dir with defaults.
   - Assert no `${templateOption:...}` strings remain.
   - Assert `DOTFILES_REPO=https://github.com/technicalpickles/dotfiles.git`, branch `main`, shell `/usr/bin/fish`, profile `fish` in `devcontainer.json`.
   - Dockerfile contains `chsh -s "/usr/bin/fish"`.
   - `post-create.sh` defaults reference the applied repo/branch (not hardcoded personal values).

2. **Shell override via env**
   - Apply with `USER_SHELL=/bin/bash USER_SHELL_NAME=bash DOTFILES_REPO=https://github.com/example/dots.git DOTFILES_BRANCH=custom`.
   - Assert repo/branch/shell/profile match expectations in `devcontainer.json`.
   - Dockerfile `chsh` uses `/bin/bash`.

3. **Profile-name derivation**
   - Apply with `USER_SHELL=/bin/zsh` and no `USER_SHELL_NAME`.
   - Assert default profile name derived from basename (`zsh`) and path `/bin/zsh` are used across files.

4. **Placeholder guard**
   - In each applied tree, `rg '${templateOption'` fails (exit non-zero).

## Clean-up

Temp dirs are created under `/tmp/devcontainer-*-XXXX`. Optionally remove them in `teardown` once debugging is done.\*\*\*
