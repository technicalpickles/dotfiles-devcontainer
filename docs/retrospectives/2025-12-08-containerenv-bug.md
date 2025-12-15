# Retrospective: containerEnv template replacement bug

## Date

2025-12-08

## What happened

- Running `devcontainer up` on a devcontainer created via `bin/apply local-dev` produced strange environment variables: `-e 0={ -e 1=}`.
- The devcontainer CLI appeared to hang after starting the container, never proceeding to `postCreateCommand`.
- Investigation revealed two separate issues:
  1. A `containerEnv` template replacement bug (fixed)
  2. A CLI hang issue that persists regardless of the containerEnv fix (unresolved)

## Root cause: containerEnv bug

The `bin/apply` script used `sed` to replace template placeholders in `devcontainer.json`. The template had:

```json
"containerEnv": "${templateOption:installEnvVars}",
```

When `sed` replaced `${templateOption:installEnvVars}` with `{}`, it produced:

```json
"containerEnv": "{}",
```

This is a **string** containing `"{}"`, not a JSON **object** `{}`.

The devcontainer CLI parsed this string character-by-character, interpreting each character as a key-value pair:

- Index 0 → `{`
- Index 1 → `}`

Resulting in docker run args: `-e 0={ -e 1=}`

## Fix

Replaced sed-based replacement with Python-based JSON-aware replacement in `bin/apply`:

```python
# Replace containerEnv as proper JSON object (not string)
obj['containerEnv'] = json.loads(container_env_json)
```

This ensures `containerEnv` is set as a proper JSON object, not a quoted string.

Commit: `5a64294` - "Fix containerEnv template replacement to produce JSON object instead of string"

## Unresolved: devcontainer up hang

Even with the `containerEnv` fix, `devcontainer up` still hangs after the container starts. Observations:

- Container builds and starts successfully
- Entrypoint runs correctly (dockerd starts, `sleep infinity` runs)
- Container is fully functional (`devcontainer exec` works)
- CLI hangs after container start, never proceeds to `postCreateCommand`
- Issue occurs with or without DinD feature
- Issue occurs across CLI versions (0.72.0 and 0.80.3)
- Environment: macOS with Colima (Docker context: `colima-gusto`)

### Hypothesis

The hang appears related to how the devcontainer CLI manages container lifecycle with Colima. The CLI uses `docker events` to detect container starts and manages streams via `-a STDOUT -a STDERR`. Something in this interaction may be blocking progress.

### Workaround

```bash
# Start container in background (will hang)
timeout 60 devcontainer up --workspace-folder . &

# Wait for container to be ready
sleep 10

# Run post-create manually
devcontainer exec --workspace-folder . -- bash .devcontainer/post-create.sh
```

Or use VS Code's Dev Containers extension which uses different code paths.

## Validation steps

For the containerEnv fix:

```bash
# Apply template
bin/apply local-dev ~/workspace/dotfiles

# Verify containerEnv is an object, not string
grep containerEnv ~/workspace/dotfiles/.devcontainer/devcontainer.json
# Should show: "containerEnv": {},
# NOT: "containerEnv": "{}",

# Run devcontainer up and check no bogus env vars
devcontainer up --workspace-folder ~/workspace/dotfiles --log-level trace 2>&1 | grep '\-e [0-9]='
# Should return no matches
```

## Takeaways

1. **JSON template replacement requires JSON-aware tools** - Using `sed` for JSON manipulation can produce syntactically correct but semantically wrong results (strings instead of objects).

2. **Separate symptoms from root causes** - The bogus env vars and the hang appeared related but were actually independent issues. Fixing one didn't fix the other.

3. **Colima/alternative Docker runtimes may have edge cases** - The hang issue may be specific to Colima's implementation of Docker APIs. Testing with Docker Desktop could help isolate.

4. **devcontainer exec is a useful fallback** - When `up` hangs, `exec` can still interact with the running container to complete setup manually.

## Related issues

- devcontainers/cli#556 - "Shell hangs from CLI, works from Visual Studio (OS X)" - Similar symptoms, closed in July 2023
- The hang issue may warrant a new bug report to devcontainers/cli with Colima-specific details
