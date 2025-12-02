# Quickstart: Base Post-Create Entrypoint Shim

1. **Add base entrypoint**: Include `/usr/local/bin/devcontainer-post-create` in the base image build, running shared steps (dotfiles sync, shell/prompt refresh, git safe-directory, optional submodule init) and honoring skip flags (`SKIP_*`).
2. **Slim templated shim**: Refactor `src/dotfiles/.devcontainer/post-create.sh` to export templated `DOTFILES_REPO/BRANCH`, run optional hook at `/workspace/.devcontainer/hooks/post-create` in `HOOK_ORDER` (`before` default), then invoke the base entrypoint and propagate failures.
3. **Tests**: Update `test/apply.bats` (and base smoke/Goss if image changes) to assert no placeholders remain, delegation occurs, hook ordering works, and missing/failed base entrypoint surfaces a clear error.
4. **Docs**: Note delegation, hook path/order, skip flags, and expected failure messaging in README/docs so consumers know where to customize without editing shared logic.
