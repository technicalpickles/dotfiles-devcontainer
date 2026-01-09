# SSH Agent Forwarding Feature Design

## Purpose

Enable Git operations over SSH (e.g., `git@github.com:...`) from within devcontainers by forwarding the host's SSH agent.

This complements the existing `GITHUB_TOKEN` forwarding, which remains necessary for GitHub API access (gh CLI, releases, etc.).

## Use Case

Developers who prefer SSH URLs for Git operations and already have SSH keys configured with their Git provider.

## Findings from Investigation

### Host Environment (macOS)

- `SSH_AUTH_SOCK` is set to launchd socket: `/private/tmp/com.apple.launchd.*/Listeners`
- Socket exists and is accessible
- Keys are loaded (`ssh-add -l` shows ED25519 key)
- `ssh -T git@github.com` authenticates successfully

### Colima Challenge

Direct socket mounting from macOS into Docker containers **does not work** because:

1. Colima runs Docker inside a Linux VM (using macOS Virtualization.Framework)
2. The macOS `SSH_AUTH_SOCK` path is not accessible from within the VM
3. Mounting `$SSH_AUTH_SOCK` from the host results in "Connection refused"

### Solution: Two-Part Configuration

Colima has native SSH agent forwarding, but the socket path inside the VM is dynamic (`/tmp/ssh-*/agent.*`). Docker containers need a stable path to mount.

#### Part 1: Enable Colima agent forwarding

```yaml
# ~/.colima/<profile>/colima.yaml
forwardAgent: true
```

#### Part 2: Create stable socket path via provision script

```yaml
# ~/.colima/<profile>/colima.yaml
provision:
  - mode: user
    script: |
      # Create stable symlink for SSH agent socket
      sudo ln -sf "$SSH_AUTH_SOCK" /run/host-ssh-agent.sock
```

This creates `/run/host-ssh-agent.sock` pointing to the dynamic socket path, which Docker containers can reliably mount.

### Verified Working

```bash
# Inside container with mount
$ ssh-add -l
256 SHA256:35/BWyXEBAK7rFxx8ZtCANjrguYIvNV6skt8Oc0VAxU  (ED25519)

$ ssh -T git@github.com
Hi technicalpickles! You've successfully authenticated, but GitHub does not provide shell access.
```

## Design

### Feature Structure

```text
src/dotfiles/.devcontainer/features/ssh-agent/
├── devcontainer-feature.json
├── install.sh
└── bin/
    └── check-ssh-agent
```

### devcontainer-feature.json

```json
{
  "id": "ssh-agent",
  "version": "0.1.0",
  "name": "SSH Agent Forwarding",
  "description": "Forwards host SSH agent for Git operations over SSH",
  "documentationURL": "https://github.com/technicalpickles/dotfiles-devcontainer",
  "options": {},
  "mounts": [
    {
      "source": "/run/host-ssh-agent.sock",
      "target": "/run/host-ssh-agent.sock",
      "type": "bind"
    }
  ],
  "containerEnv": {
    "SSH_AUTH_SOCK": "/run/host-ssh-agent.sock"
  }
}
```

**Note:** The mount source is the stable path created by the Colima provision script, not `${localEnv:SSH_AUTH_SOCK}`.

### install.sh

Installs the health check script:

```bash
#!/bin/bash
set -e

# Install health check script
mkdir -p /usr/local/bin
cp bin/check-ssh-agent /usr/local/bin/
chmod +x /usr/local/bin/check-ssh-agent

echo "SSH agent forwarding configured."
echo "Run 'check-ssh-agent' to verify setup."
```

### Health Check Script (`bin/check-ssh-agent`)

A diagnostic script to verify SSH agent forwarding is working and provide actionable guidance when it's not.

**Checks:**

1. Is `SSH_AUTH_SOCK` environment variable set?
2. Does the socket file exist at that path?
3. Can we connect to the agent? (`ssh-add -l`)
4. Can we authenticate to GitHub? (`ssh -T git@github.com`)

**Output Examples:**

Success:

```text
✓ SSH_AUTH_SOCK is set: /run/host-ssh-agent.sock
✓ Socket exists
✓ Agent is accessible (1 key loaded)
✓ GitHub authentication successful (technicalpickles)
```

Failure with guidance:

```text
✗ Agent connection failed: Connection refused

This usually means SSH agent forwarding is not configured on your Colima VM.

Required Colima configuration (~/.colima/<profile>/colima.yaml):

  forwardAgent: true

  provision:
    - mode: user
      script: |
        sudo ln -sf "$SSH_AUTH_SOCK" /run/host-ssh-agent.sock

After editing, restart Colima:
  colima restart --profile <profile>

Also verify your SSH agent has keys loaded:
  ssh-add -l
```

## Prerequisites for Users

### Colima Configuration

Add to `~/.colima/<profile>/colima.yaml`:

```yaml
# Enable SSH agent forwarding from macOS to VM
forwardAgent: true

# Create stable socket path for Docker containers
provision:
  - mode: user
    script: |
      sudo ln -sf "$SSH_AUTH_SOCK" /run/host-ssh-agent.sock
```

Then restart Colima:

```bash
colima restart --profile <profile>
```

### Host Requirements

Ensure SSH agent is running with keys loaded:

```bash
ssh-add -l  # Should show loaded keys
```

## Testing Strategy

### Feature Tests (`test/features/ssh-agent/test.sh`)

Validate feature metadata:

- Mount source is `/run/host-ssh-agent.sock`
- Mount target is `/run/host-ssh-agent.sock`
- `SSH_AUTH_SOCK` env var is set to `/run/host-ssh-agent.sock`
- `check-ssh-agent` script is included

### Integration Test

With Colima properly configured:

```bash
# Inside devcontainer
ssh-add -l                    # Should list keys
ssh -T git@github.com         # Should authenticate
check-ssh-agent               # Should show all green
```

### Health Check Tests

Validate the diagnostic script outputs correct guidance for various failure modes.

## Decisions

1. **Health check location:** Lives in the ssh-agent feature (installed to `/usr/local/bin/check-ssh-agent`)

2. **Platform scope:** Colima only for initial implementation. Docker Desktop and Windows/WSL out of scope.

3. **Socket path:** Hardcoded `/run/host-ssh-agent.sock` rather than dynamic detection. Users must configure the Colima provision script.

## Implementation Steps

1. Create `ssh-agent` feature with stable mount path
2. Create `check-ssh-agent` diagnostic script
3. Add feature tests
4. Test with properly configured Colima
5. Document prerequisites (Colima config) in feature docs
6. Publish feature to GHCR
