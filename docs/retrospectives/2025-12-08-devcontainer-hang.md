# Retrospective: devcontainer up hang (DinD entrypoint fallback)

## What happened

- Running `devcontainer up` in `~/workspace/dotfiles` appeared to hang after dockerd reported ready. Logs showed the DinD entrypoint defaulting to `exec /usr/bin/fish`, which is absent in that image, so PID 1 exited and the CLI sat streaming the tail.
- In this repo (`pickled-devcontainer`), the updated entrypoint was already using a safe fallback, so `devcontainer up` completed quickly.
- A 40s timeout on `devcontainer up` with `--build-no-cache` was also masking progress by killing the build before export; removing `--build-no-cache` avoided that noise.

## Root cause

- The vendored feature in `~/workspace/dotfiles/.devcontainer/features/dind/install.sh` still defaulted to `/usr/bin/fish` when no command was provided. On images without fish, the entrypoint immediately exited.
- The repo-level fix (sleep fallback) had not been applied to the vendored copy consumed by the dotfiles project.

## Fix

- Added a resilient fallback to `sleep infinity` when no command is provided in `src/dotfiles/.devcontainer/features/dind/install.sh`, then reapplied the feature to `~/workspace/dotfiles`, updating its `install.sh` accordingly.
- Additional logging was already in place (dockerd start message, periodic tails, exec handoff).

## Validation steps

- `npx @devcontainers/cli up --workspace-folder <repo> --remove-existing-container --log-level trace`
- `npx @devcontainers/cli exec --workspace-folder <repo> -- true`
- `npx @devcontainers/cli exec --workspace-folder <repo> -- /bin/bash` (attach shell)
- If using local feature source: `bin/apply local-dev ~/workspace/dotfiles` to pull updated `dind` feature before rebuilding.

## Takeaways

- Vendored features must be refreshed after entrypoint changes; otherwise consuming repos keep old defaults.
- Defaulting to a guaranteed command (`sleep infinity`) keeps PID 1 alive and matches upstream dind behavior, avoiding hangs when shells are missing.
- Avoid `--build-no-cache` for iterative debugging unless necessary; it can exceed timeouts and obscure root causes.\*\*\*
