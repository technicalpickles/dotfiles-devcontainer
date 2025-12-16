# AWS CLI Credentials Mount Feature

This feature mounts the host's `~/.aws` directory into the container for AWS CLI credential access.

## Usage

```json
"features": {
  "ghcr.io/technicalpickles/devcontainer-features/aws-cli:0.1.0": {}
}
```

## What This Feature Does

- Mounts `~/.aws` from host to `/home/vscode/.aws` in container (read-only)
- Allows AWS CLI and SDKs to access credentials configured on the host

## What This Feature Does NOT Do

- Install AWS CLI (use base image or another feature)
- Create the `~/.aws` directory on the host (use `initializeCommand`)

## Prerequisites

Ensure `~/.aws` exists on the host. Add to your `devcontainer.json`:

```json
"initializeCommand": "mkdir -p ${localEnv:HOME}/.aws"
```

## Authentication Flow

1. Run `aws sso login` on host machine (opens browser)
2. Credentials cached in `~/.aws/sso/cache/`
3. Container reads credentials via mount
4. AWS CLI/SDKs work transparently
