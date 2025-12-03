# DinD Feature Notes

## Versions and digests

| Version | Digest                    | Notes                                                                        |
| ------- | ------------------------- | ---------------------------------------------------------------------------- |
| v0.1.0  | _TBD after first publish_ | Initial published wiring-only DinD feature aligned to base image Docker bits |

## Publish checklist (maintainers)

- Package and publish from repo root:
  - `bin/publish-dind-feature` (local) or CI workflow (see `.github/workflows/feature-publish.yaml`)
- Record the published version and digest in the table above.
- Update template reference in `src/dotfiles/.devcontainer/devcontainer.json` to the new version/digest.
- Run `bats test/apply.bats` to ensure template consumption does not vendor feature files.
- Run feature validation harness under `test/features/dind/` if modified.

## Consumer notes

- Template consumes the published DinD feature by reference; no `.devcontainer/features` folder should be present in applied repos.
- Docker engine components must be baked into the base image; this feature provides wiring/entrypoint only.
- Pin to specific versions/digests in the `features` block to control upgrades and outage fallbacks.

## Pinning and outage fallback

1. Pin the published feature (version or digest) in `src/dotfiles/.devcontainer/devcontainer.json` and rebuild.
2. If GHCR is unavailable, retry pulls with the pinned version/digest; do not float to `latest`.
3. If outages persist, temporarily vendor the feature files from `src/dotfiles/.devcontainer/features/dind/` with a clear cleanup reminder to remove them once registry access returns.
4. After recovery, restore the pinned GHCR reference and remove any vendored feature files from consuming repos.

## Validation status

- `bats test/apply.bats`: pass (template references GHCR DinD and no vendored features).
- `test/features/dind/test.sh`: currently skips when `dockerd` is unavailable; set `REQUIRE_DOCKER=true` when running in a base-image/devcontainer context that includes Docker engine bits.
