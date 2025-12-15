# Devcontainer CLI Reference

This documents behaviors of `@devcontainers/cli` that affect local testing and CI workflows.

## Command Behaviors

### `devcontainer up`

Builds the image (if needed) and starts the container.

**Critical:** This command blocks differently based on container state.

| Container State | Behavior                                                   |
| --------------- | ---------------------------------------------------------- |
| Not running     | Blocks indefinitely, keeping container alive in foreground |
| Already running | Exits immediately with success                             |

**Why this matters:**

- Scripts that call `devcontainer up` and expect it to return will hang
- The command appears "stuck" but is actually working correctly
- Ctrl+C kills the container

**Workaround for scripts:** Use `--id-label` to identify your container, then run `devcontainer exec` separately:

```bash
# Start container (blocks)
devcontainer up --id-label "my-test=foo" --workspace-folder ./my-project &
UP_PID=$!

# Wait for container to be ready, then exec
sleep 5  # or poll for readiness
devcontainer exec --id-label "my-test=foo" --workspace-folder ./my-project /bin/sh -c "echo hello"

# Clean up
kill $UP_PID
```

### `devcontainer exec`

Runs a command in an already-running container. Exits when the command completes.

```bash
devcontainer exec --workspace-folder ./my-project /bin/sh -c "npm test"
```

Requires the container to already be running (via `devcontainer up`).

### `devcontainer build`

Builds the image without starting a container. Exits when the build completes.

```bash
devcontainer build --workspace-folder ./my-project
```

Use this when you only need to verify the image builds successfully.

## Patterns

### CI Workflows

CI jobs typically don't need special handling. The job runs `devcontainer up`, which blocks and keeps the container alive. When the job completes (or times out), the process dies and so does the container.

```yaml
- name: Build and start devcontainer
  run: devcontainer up --workspace-folder .

- name: Run tests
  run: devcontainer exec --workspace-folder . /bin/sh -c "./test.sh"
```

### Local Scripted Testing

For scripts like `bin/smoke-test`, the pattern is:

1. Call `devcontainer up` (it returns because it also builds and creates)
2. Call `devcontainer exec` to run tests
3. Clean up containers when done

The key insight: `devcontainer up` returns after building and creating, but if you call it again on an already-running container, it exits immediately.

### Interactive Development

For interactive work, just run `devcontainer up` in a terminal. It blocks and keeps your container alive. Open another terminal to run `devcontainer exec` commands, or use VS Code's "Reopen in Container" which handles this automatically.

## Common Gotchas

| Symptom                                 | Cause                                  | Fix                                            |
| --------------------------------------- | -------------------------------------- | ---------------------------------------------- |
| Script hangs after `devcontainer up`    | Command blocks to keep container alive | Run in background or use exec pattern          |
| `exec` fails with "container not found" | Container not running yet              | Ensure `up` completed first                    |
| Container dies unexpectedly             | Parent `up` process was killed         | Keep `up` process alive or use Docker directly |
