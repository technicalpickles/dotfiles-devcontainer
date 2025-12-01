<!--
Sync Impact Report
- Version: unversioned template → 1.0.0
- Modified principles: placeholder → I. User-Owned Environment (Generic by Default); placeholder → II. Reproducible Base Image & Template Integrity; placeholder → III. Security Boundaries & Host-Managed Credentials; placeholder → IV. Test-First Template Verification (Non-Negotiable); placeholder → V. Clarity & Developer Experience
- Added sections: Platform & Component Constraints; Workflow & Quality Gates
- Removed sections: none
- Templates requiring updates: ✅ .specify/templates/plan-template.md; ✅ .specify/templates/spec-template.md; ✅ .specify/templates/tasks-template.md; ✅ .specify/templates/agent-file-template.md
- Follow-up TODOs: none
-->

# Dotfiles Dev Container Constitution

## Core Principles

### I. User-Owned Environment (Generic by Default)

The template MUST remain provider-agnostic: no hardcoded personal dotfiles, secrets, or org-specific values. Defaults come from template options or auto-detection with explicit overrides always respected. Shell and dotfiles choices must propagate through `devcontainer.json`, `Dockerfile`, and post-create scripts without drift. Rationale: protects portability so any developer can apply the template safely.

### II. Reproducible Base Image & Template Integrity

All devcontainers MUST build from `ghcr.io/technicalpickles/dotfiles-devcontainer/base:latest` (pinned digest in code/CI) and reuse `setup-dotfiles` instead of re-implementing installs. Keep layers lean, avoid duplicating features already in the base image, and prefer image rebuilds over ad-hoc package installs. Rationale: predictable builds, smaller diffs, and faster pulls.

### III. Security Boundaries & Host-Managed Credentials

AWS SSO credentials remain on the host; the container only receives a read-only mount of `~/.aws` and runs as the `vscode` user. Never bake credentials or long-lived secrets into images, scripts, or defaults, and avoid widening permissions (no write mounts to host credential stores). Rationale: maintains trust boundaries while enabling necessary cloud access.

### IV. Test-First Template Verification (Non-Negotiable)

Template and image changes MUST be backed by automated checks: `bats test/apply.bats` to guard templating and option propagation, and base-image smoke/Goss tests to verify required tooling and `setup-dotfiles`. Add or update tests before implementing behavioral changes; failing tests precede fixes. Rationale: prevents regressions in generated devcontainers.

### V. Clarity & Developer Experience

Documentation and tooling MUST make the zero-config path obvious (auto-detect dotfiles repo, sane defaults) while clearly describing overrides, AWS SSO workflow, and macOS performance guidance (volume-based workflow). Helper scripts (`bin/apply`, `bin/build`, `bin/run`, `bin/stop`) should remain the primary UX and emit actionable messages when detection or validation is uncertain. Rationale: smooth onboarding reduces support load.

## Platform & Component Constraints

- Base from `ghcr.io/technicalpickles/dotfiles-devcontainer/base` (pinned digest; keep `vscode` UID/GID). Do not add duplicate tooling already shipped (fish, starship, gh, mise, AWS CLI, 1Password CLI).
- Use `setup-dotfiles --repo <url> --branch <name> --env DOCKER_BUILD=true` in images and post-create; favor idempotent syncs over manual git commands.
- Default shell is fish; alternate shells are allowed but MUST be fully propagated (devcontainer profiles, `chsh` in Dockerfile, tests).
- Credential mounts remain read-only; additional host mounts require security review with rationale.
- Devcontainer feature set stays minimal: keep docker-in-docker for daemon wiring; add new features only when not covered by the base image and justified by tests.

## Workflow & Quality Gates

- Preferred entrypoints: `bin/apply` for templating, `bin/build`/`bin/run` for local validation, `bin/stop` for cleanup. CI publishes base image and template artifacts; use the tested image in publishes (no rebuild-before-push).
- Every change that touches template options, shell handling, or dotfiles flow MUST exercise `bats test/apply.bats` (or equivalent) before merge; base image or dependency shifts require matching smoke/Goss coverage.
- When adding auto-detection or UX changes, emit clear logs (success, warning on inconsistencies, explicit override acknowledgment) and document the behavior in README/docs.
- Keep macOS performance guidance current (container volume workflow) and ensure any new mounts or features are covered in documentation and scripts.
- Renovate or dependency updates affecting the base image digest or devcontainer features MUST include validation evidence in the change description.

## Governance

- Amendments require a PR describing the rationale, expected impact, updated tests/docs, and alignment with these principles. Backward-incompatible workflow changes or principle redefinitions trigger a MAJOR version bump; new principles or material expansions trigger MINOR; clarifications only trigger PATCH.
- Compliance is checked during code review: verify no personal defaults, base image pinning intact, security boundaries preserved, and required tests updated/passing. Reviewers may block if automated checks for template integrity are missing.
- Ratification is recorded on initial adoption; every merged amendment updates `Last Amended` and the semantic version in this file. Keep the Sync Impact Report accurate when propagating changes to templates and guidance.

**Version**: 1.0.0 | **Ratified**: 2025-12-01 | **Last Amended**: 2025-12-01
