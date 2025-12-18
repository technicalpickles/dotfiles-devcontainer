# Architecture

This document describes the pickled-devcontainer system architecture and key constraints.

## System Overview

A Dev Container ecosystem with three published artifacts:

1. **Base Image** (`ghcr.io/.../base`) - Ubuntu with pre-installed tools
2. **Features** (`ghcr.io/.../dind`, `.../aws-cli`) - Composable container extensions
3. **Template** (`ghcr.io/.../dotfiles`) - Applied to target repos

```text
┌─────────────────────────────────────────────────┐
│              Target Repository                   │
│  ┌───────────────────────────────────────────┐  │
│  │         .devcontainer/                     │  │
│  │  ┌─────────────┐  ┌────────────────────┐  │  │
│  │  │ Dockerfile  │  │ devcontainer.json  │  │  │
│  │  │ (FROM base) │  │ (refs features)    │  │  │
│  │  └─────────────┘  └────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌─────────────────────────┐
│   Base Image    │  │   Published Features    │
│  (GHCR, pinned) │  │  (GHCR, versioned)      │
└─────────────────┘  └─────────────────────────┘
```

---

## Base Image

**Registry:** `ghcr.io/technicalpickles/dotfiles-devcontainer/base`
**Source:** [`docker/base/`](docker/base/)
**Constraint:** Always pinned by SHA256 digest in devcontainer.json

### Contents

Pre-installed tools (no duplication in features/template):

- Fish shell, Starship prompt
- gh CLI, mise, tmux
- AWS CLI v2, 1Password CLI
- Docker engine components (daemon bits for DinD feature)

### Scripts

| Script                     | Location in Image | Called When                             |
| -------------------------- | ----------------- | --------------------------------------- |
| `setup-dotfiles`           | `/usr/local/bin/` | Build time (Dockerfile) and post-create |
| `devcontainer-post-create` | `/usr/local/bin/` | Post-create entrypoint                  |

### Base Image Execution Flow

```text
[Image Build]
    └── setup-dotfiles --repo X --branch Y --env DOCKER_BUILD=true
        └── Clones dotfiles, runs install.sh

[Container Start]
    └── devcontainer-post-create
        ├── setup-dotfiles (sync/update)
        ├── Configure git safe.directory
        ├── Run project hook (if exists)
        └── Refresh shell prompt
```

### Base Image Constraints

- Retains `vscode` UID/GID for host permission compatibility
- Docker engine baked in, but wiring is feature's responsibility
- Build secrets for tokens (never layer-persisted)

**Cross-links:**

- Design rationale: [docs/plans/2025-11-27-base-image-plan.md](docs/plans/2025-11-27-base-image-plan.md)
- Multi-arch spec: [specs/001-multi-arch-base/spec.md](specs/001-multi-arch-base/spec.md)

---

## Features

Published devcontainer features that compose onto the base image.

**Registry:** `ghcr.io/technicalpickles/devcontainer-features/`
**Source:** [`src/dotfiles/.devcontainer/features/`](src/dotfiles/.devcontainer/features/)

### Published Features

| Feature   | Purpose                 | Key Mechanism                       |
| --------- | ----------------------- | ----------------------------------- |
| `dind`    | Docker-in-Docker wiring | Privileged mode, mounts, entrypoint |
| `aws-cli` | AWS credentials access  | Read-only bind mount of `~/.aws`    |

### Feature Anatomy

```text
features/{name}/
├── devcontainer-feature.json   # Metadata: mounts, env, entrypoints
└── install.sh                  # Informational (actual setup via metadata)
```

**Design principle:** Features are metadata-driven, not install.sh-heavy. The base image has the tools; features wire them.

### Feature Execution Flow

```text
[Container Creation]
    └── devcontainer processes features block
        └── For each feature:
            ├── Apply mounts (e.g., ~/.aws → /home/vscode/.aws)
            ├── Set containerEnv
            ├── Configure entrypoint (e.g., start-dind.sh)
            └── Run install.sh (informational only)

[DinD Feature Specifically]
    └── Entrypoint: /usr/local/share/dind/start-dind.sh
        ├── Start dockerd
        ├── Wait for ready
        └── exec to user command or sleep infinity
```

### Feature Constraints

- Features reference base image capabilities, don't duplicate
- Versioned with semver, pinned by digest for reproducibility
- No secrets baked; credentials via mounts or runtime env

**Cross-links:**

- Feature registry: [docs/features.md](docs/features.md)
- DinD spec: [specs/003-publish-dind-feature/spec.md](specs/003-publish-dind-feature/spec.md)
- AWS credentials design: [docs/plans/2025-11-10-aws-sso-credentials-design.md](docs/plans/2025-11-10-aws-sso-credentials-design.md)

---

## Template

The devcontainer template applied to target repositories.

**Registry:** `ghcr.io/technicalpickles/dotfiles-devcontainer/dotfiles`
**Source:** [`src/dotfiles/`](src/dotfiles/)

### What Gets Generated

When `bin/apply` runs against a target repo:

```text
target-repo/
└── .devcontainer/
    ├── devcontainer.json    # Refs base image + features
    ├── Dockerfile           # FROM base, calls setup-dotfiles
    └── post-create.sh       # Thin shim → devcontainer-post-create
```

No feature files are copied - they're pulled from GHCR at build time.

### bin/apply Script

**Source:** [`bin/apply`](bin/apply) (27KB, complex)

| Responsibility                 | Details                                      |
| ------------------------------ | -------------------------------------------- |
| Dotfiles auto-detection        | env var → git config → local dirs → gh CLI   |
| URL normalization              | SSH → HTTPS for container auth compatibility |
| Feature ref handling           | Varies by MODE (see below)                   |
| Template variable substitution | `${templateOption:name}` syntax              |

### Application Modes

| Mode          | Feature Refs                   | Use Case                        |
| ------------- | ------------------------------ | ------------------------------- |
| `local-dev`   | Vendored in repo               | Developing unpublished features |
| `ci-unpinned` | Published tags                 | General use (default)           |
| `ci-pinned`   | Requires digest in env         | CI reproducibility              |
| `release`     | Requires digest, no local refs | Release builds                  |

**Why modes exist:** Prevents accidental use of unpublished features in releases while allowing local iteration during development.

### Template Application Flow

```text
[bin/apply <mode> <target>]
    ├── Detect/validate dotfiles repo
    ├── Normalize git URLs
    ├── Validate feature refs for mode
    ├── Copy template to target
    ├── Substitute template variables
    └── Output: .devcontainer/ ready to build
```

**Cross-links:**

- Auto-detection design: [docs/plans/2025-11-10-dotfiles-auto-detection-design.md](docs/plans/2025-11-10-dotfiles-auto-detection-design.md)

---

## Security Boundaries

Credentials are never baked into images or container definitions.

### Credential Handling

| Credential       | Mechanism                          | Lifecycle                             |
| ---------------- | ---------------------------------- | ------------------------------------- |
| **AWS**          | Read-only bind mount of `~/.aws`   | Host manages auth via `aws sso login` |
| **GitHub Token** | Build secret + runtime `remoteEnv` | Sourced fresh from host each time     |

### AWS Credentials

```text
Host                          Container
~/.aws/ ──── read-only ────► /home/vscode/.aws/
   │                              │
   └── aws sso login              └── aws cli/SDK reads
       (browser auth)                 (no write access)
```

**Why read-only:** Container is credential consumer, not manager. Prevents corruption, permission issues, and maintains host as source of truth.

### GitHub Token

```text
[Build Time]
    └── Docker build secret (--mount=type=secret)
        └── Available during RUN, never persisted in layers

[Post-Create + Runtime]
    └── remoteEnv: GITHUB_TOKEN=${localEnv:GITHUB_TOKEN}
        └── Forwarded from host at container start
```

**Token resolution priority:**

1. `$GITHUB_TOKEN` environment variable
2. `fnox get GITHUB_TOKEN`
3. `gh auth token`
4. Graceful degradation (may hit rate limits)

### Invariants

- **Never baked:** No credentials in Dockerfile ARGs, image layers, or devcontainer.json
- **Never written:** No writable mounts to host credential stores
- **Per-developer:** Each developer uses their own tokens from their own host
- **Auditable:** API usage traceable by token

**Cross-links:**

- AWS design: [docs/plans/2025-11-10-aws-sso-credentials-design.md](docs/plans/2025-11-10-aws-sso-credentials-design.md)
- GitHub token design: [docs/plans/2025-12-11-github-token-auth-design.md](docs/plans/2025-12-11-github-token-auth-design.md)
- Constitution: [.specify/memory/constitution.md](.specify/memory/constitution.md)

---

## CI/CD & Publishing

All artifacts published to GitHub Container Registry (GHCR) with validation gates.

### Artifact Flow

```text
[Base Image]
    Source: docker/base/
    Build: Multi-arch (linux/amd64, linux/arm64) via Buildx + QEMU
    Test: Goss per architecture
    Publish: Candidate → validate → promote to release

[Features]
    Source: src/dotfiles/.devcontainer/features/
    Package: devcontainer features package
    Test: Feature-specific test.sh
    Publish: bin/publish-feature → GHCR

[Template]
    Source: src/dotfiles/
    Publish: devcontainers/action@v1 → GHCR
```

### Multi-Architecture Strategy

```text
GitHub Actions (public runners)
    │
    ├── docker/setup-qemu-action
    ├── docker/setup-buildx-action
    │
    └── docker/build-push-action
        ├── linux/amd64 ──► test with Goss ──► ✓
        └── linux/arm64 ──► test with Goss ──► ✓
                                               │
                                               ▼
                                    Multi-arch manifest pushed
```

**Why public runners:** Buildx + QEMU sufficient; no self-hosted hardware required.

### Validation Gates

| Gate                   | Enforces                                    |
| ---------------------- | ------------------------------------------- |
| Any architecture fails | Block entire release (no partial publishes) |
| Goss tests fail        | Block promotion to release tags             |
| Feature dry-run fails  | Block PR merge                              |
| BATS tests fail        | Block PR merge                              |

**Principle:** Only publish what's been tested. Candidate tags are tested before promotion.

### Pinning Strategy

| Artifact   | Reference Style          | Why                                         |
| ---------- | ------------------------ | ------------------------------------------- |
| Base image | SHA256 digest            | Reproducible builds across rebuilds         |
| Features   | Version + digest         | Semver for humans, digest for determinism   |
| Template   | Latest (consumer choice) | Template is starting point, not runtime dep |

**Cross-links:**

- CI reference: [docs/ci.md](docs/ci.md)
- Multi-arch spec: [specs/001-multi-arch-base/spec.md](specs/001-multi-arch-base/spec.md)
- Feature publishing: [docs/features.md](docs/features.md)

---

## Testing Strategy

Three testing layers, each validating different artifacts.

### Testing Layers

```text
┌─────────────────────────────────────────────────────────┐
│  BATS Tests (Unit)                                      │
│  What: Shell script logic in bin/                       │
│  When: Every PR, fast feedback                          │
│  Tool: bats test/*.bats                                 │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  Goss Tests (Base Image Validation)                     │
│  What: Installed tools, user config, script presence    │
│  When: Base image builds, per-architecture              │
│  Tool: goss validate (docker/goss.yaml)                 │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  Smoke Tests (Integration)                              │
│  What: Full devcontainer build + runtime behavior       │
│  When: Template/feature changes, pre-release            │
│  Tool: bin/smoke-test, test/dotfiles/test.sh            │
└─────────────────────────────────────────────────────────┘
```

### What Tests What

| Test                             | Scope               | Validates                                                                 |
| -------------------------------- | ------------------- | ------------------------------------------------------------------------- |
| `bats test/apply.bats`           | bin/apply           | Auto-detection, URL normalization, mode validation, template substitution |
| `bats test/publish-feature.bats` | bin/publish-feature | Feature packaging, validation flow                                        |
| `docker/goss.yaml`               | Base image          | Tools present, vscode user exists, scripts executable                     |
| `test/dotfiles/test.sh`          | Template            | Dotfiles cloned, shell configured, tools work                             |
| `test/features/dind/test.sh`     | DinD feature        | Docker daemon running, docker commands work                               |
| `test/features/aws-cli/test.sh`  | AWS feature         | ~/.aws mounted, aws cli accessible                                        |

### Running Tests

```bash
# Unit tests (fast, no container)
bats test/apply.bats
bats test/publish-feature.bats

# Base image validation
./bin/build-base && ./bin/test-base

# Full smoke test (builds container, runs integration)
./bin/smoke-test
./bin/smoke-test --keep-artifacts  # Debug failures
```

### Why These Tools

| Tool            | Why Chosen                                                                  |
| --------------- | --------------------------------------------------------------------------- |
| **BATS**        | Bash-native, test shell scripts in their own language, good fixture support |
| **Goss**        | Declarative container validation, runs per-architecture, fast               |
| **Smoke tests** | Real devcontainer CLI, catches integration issues unit tests miss           |

**Cross-links:**

- CLI gotchas: [docs/devcontainer-cli.md](docs/devcontainer-cli.md)
- Debugging lessons: [docs/retrospectives/](docs/retrospectives/)

---

## Guiding Principles

Core invariants from the [project constitution](.specify/memory/constitution.md):

| Principle                   | Implication                                                                              |
| --------------------------- | ---------------------------------------------------------------------------------------- |
| **User-Owned Environment**  | No hardcoded personal dotfiles, secrets, or org-specific values. Template stays generic. |
| **Reproducible Builds**     | Pinned digests, deterministic feature refs, tested before publish.                       |
| **Security Boundaries**     | Read-only credential mounts, no baked secrets, vscode user only.                         |
| **Test-First Verification** | Tests precede implementation; failing tests precede fixes.                               |
| **Developer Experience**    | Zero-config path obvious, clear overrides, actionable error messages.                    |

### Decision Records

Detailed rationale for major decisions lives in [`docs/plans/`](docs/plans/):

| Decision                | Document                                                                                                |
| ----------------------- | ------------------------------------------------------------------------------------------------------- |
| AWS read-only mount     | [2025-11-10-aws-sso-credentials-design.md](docs/plans/2025-11-10-aws-sso-credentials-design.md)         |
| GitHub token handling   | [2025-12-11-github-token-auth-design.md](docs/plans/2025-12-11-github-token-auth-design.md)             |
| Dotfiles auto-detection | [2025-11-10-dotfiles-auto-detection-design.md](docs/plans/2025-11-10-dotfiles-auto-detection-design.md) |
| Base image strategy     | [2025-11-27-base-image-plan.md](docs/plans/2025-11-27-base-image-plan.md)                               |

Formal specifications in [`specs/`](specs/):

- [001-multi-arch-base](specs/001-multi-arch-base/spec.md)
- [003-publish-dind-feature](specs/003-publish-dind-feature/spec.md)
