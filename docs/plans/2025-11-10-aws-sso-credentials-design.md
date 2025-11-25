# AWS SSO Credentials in Devcontainer

**Date:** 2025-11-10
**Status:** Proposed
**Approach:** Read-only bind mount of host AWS credentials

## Problem Statement

Users need access to AWS credentials inside the devcontainer to use tools like Claude (via AWS Bedrock) and other AWS services. AWS SSO requires browser-based authentication which works best on the host machine. We need a way to share credentials between host and container without complex credential management.

## Requirements

- AWS SSO authentication managed on host (browser flow)
- Credentials available inside devcontainer
- Works with default AWS profile (no profile switching needed)
- Credentials refresh a few times per day
- Simple, maintainable solution
- No security degradation

## Solution: Read-Only Mount

Mount the host's `~/.aws` directory as read-only into the devcontainer. This makes the container a consumer of credentials without allowing it to modify host AWS configuration.

### Architecture

**Authentication Flow:**
1. User runs `aws sso login` on host Mac
2. Browser opens for SSO authentication
3. Credentials cached in `~/.aws/sso/cache/` and `~/.aws/cli/cache/`
4. Container reads cached credentials via read-only mount
5. AWS SDK/CLI tools in container use credentials transparently

**Components:**
- **Host:** AWS CLI, browser for SSO auth, credential cache storage (source of truth)
- **Container:** AWS CLI/SDKs (read-only consumers), dev tools requiring AWS access
- **Mount:** `~/.aws` → `/home/vscode/.aws` (read-only bind mount)

### Implementation

**Devcontainer configuration** ([.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)):

```json
{
  "image": "mcr.microsoft.com/devcontainers/javascript-node:1-18-bullseye",
  "mounts": [
    "source=${localEnv:HOME}/.aws,target=/home/vscode/.aws,type=bind,readonly"
  ],
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/aws-cli:1": {}
  }
  // ... rest of config
}
```

**Key implementation details:**

- `source=${localEnv:HOME}/.aws` - Environment variable expansion for host home directory
- `target=/home/vscode/.aws` - Maps to container's vscode user home
- `readonly` - Prevents any writes from container
- AWS CLI feature added to ensure `aws` command available in container

### User Workflow

**Session start (on host):**
```bash
aws sso login
# Browser authenticates, credentials cached
```

**Work in container:**
- Open VS Code, reopen in container
- All AWS commands/tools work automatically
- Claude (Bedrock), deploy scripts, etc. have credentials

**Credential expiration (a few times per day):**
- Switch to host terminal
- Run `aws sso login`
- Return to container - new credentials immediately available

### What Works

✅ Claude via AWS Bedrock
✅ Any AWS SDK usage (boto3, aws-sdk-js, etc.)
✅ AWS CLI read operations (s3 ls, describe-*, get-*, list-*)
✅ Deploy tools that assume AWS credentials
✅ Works with default profile (no `--profile` flag needed)

### Known Limitations

❌ Cannot run `aws sso login` from inside container (requires browser on host)
❌ Cannot modify `~/.aws/config` from inside container
✅ Can still use `AWS_PROFILE` environment variable if profile switching needed

When credentials expire, tools will show standard AWS auth errors - this is the signal to run `aws sso login` on host.

## Design Decisions

### Why Read-Only Mount?

**Considered alternatives:**
1. **Read-write mount** - More flexible but introduces file permission issues, risk of corruption, timestamp sync problems
2. **Split mount** (config read-only, cache read-write) - More complex, still has permission risks, unclear benefit
3. **Credential copying/syncing** - Adds complexity, sync timing issues, security risks

**Read-only chosen because:**
- Simplest implementation (single mount line)
- No file permission/ownership issues (read-only eliminates write conflicts)
- Host remains single source of truth
- No risk of container corrupting AWS configuration
- Matches actual usage pattern (authenticate on host, consume in container)

### Why Not Other Approaches?

**Browser forwarding/X11:** Complex setup, fragile, unnecessary when host browser works fine

**AWS SSO device code flow:** Slower UX, still requires host interaction, no clear advantage

**Environment variable credential passing:** Requires scripting to extract/inject, more complex than mount, doesn't handle expiration well

## Security Considerations

- Read-only mount prevents container from modifying credentials or config
- AWS credential files already have restrictive permissions (600/700)
- Container user (vscode) can only read, cannot write
- No elevation of access beyond what host already has
- Standard AWS security model preserved

## Testing Plan

1. Apply mount configuration to devcontainer
2. Run `aws sso login` on host
3. Open project in devcontainer
4. Verify `aws sts get-caller-identity` works in container
5. Test Claude/Bedrock access from container
6. Let credentials expire naturally
7. Verify re-running `aws sso login` on host restores container access

## Future Enhancements

If user needs arise:
- Add SSH agent forwarding for git operations
- Add 1Password socket mount for 1Password CLI
- Document how to use `AWS_PROFILE` env var for profile switching
- Add helper aliases/functions in dotfiles for credential status checks

## References

- [Dev Containers mounts documentation](https://containers.dev/implementors/json_reference/#general-properties)
- [AWS SSO credential process](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)
- Current AWS config: `~/.aws/config` (uses `sso_start_url`, `sso_region`, etc.)
