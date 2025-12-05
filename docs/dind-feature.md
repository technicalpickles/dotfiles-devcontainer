# DinD Feature Notes

## Published versions and digests

| Version | Digest                                                                    | Notes                                                                                                                                     |
| ------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| v0.1.1  | _pending publish_                                                         | Adds publish summary JSON output + DOCKER_HOST export in start script; publish via workflow `.github/workflows/publish-dind-feature.yml`. |
| v0.1.0  | `sha256:30eeba4b20d48247dde11bbab5b813a4b3748dc34014bebec46bf28e8b658020` | Initial published wiring-only DinD feature aligned to base image Docker bits (published via workflow `feature-publish.yaml`)              |

## Base image alignment

- Current pinned base image: `ghcr.io/technicalpickles/dotfiles-devcontainer/base@sha256:3195dd842e35bc1318b06c86c849e464b23fbc2082fc5de64f4b7bcaa789a63b`
- Docker bits baked into base: Docker 29.1.2 (validated via `bin/smoke-test --template dotfiles`).
- `devcontainer.json` must keep this digest in sync with publish validation runs (see T003/T015).

## Performance baseline

| Scenario                            | Duration  | Delta vs baseline | Notes                                                    |
| ----------------------------------- | --------- | ----------------- | -------------------------------------------------------- |
| Apply + build (GHA, default opts)   | _pending_ | N/A               | Capture with `bin/apply` + `bin/build` (see quickstart). |
| Docker verification (`docker info`) | _pending_ | N/A               | Use prebaked Docker bits; record pass/fail.              |

## Outage notes

| Date      | Impact                                       | Mitigation                                                  |
| --------- | -------------------------------------------- | ----------------------------------------------------------- |
| _pending_ | _No recorded GHCR outages for DinD feature._ | Retry with pinned version/digest; see fallback steps below. |

## Publish checklist (maintainers)

- Package and publish from repo root:
  - `bin/publish-dind-feature` (local) or CI workflow (see `.github/workflows/publish-dind-feature.yml`)
- Record the published version and digest in the table above.
- Update template reference in `src/dotfiles/.devcontainer/devcontainer.json` to the new version/digest.
- Run `bats test/apply.bats` to ensure template consumption does not vendor feature files.
- Run feature validation harness under `test/features/dind/` if modified.

## Consumer notes

- Template consumes the published DinD feature by reference; no `.devcontainer/features` folder should be present in applied repos.
- Docker engine components must be baked into the base image; this feature provides wiring/entrypoint only.
- Pin to specific versions/digests in the `features` block to control upgrades and outage fallbacks.

## Security and privilege notes

- DinD requires privileged containers; ensure hosts/CI runners permit privileged builds.
- Host `~/.aws` remains mounted read-only from `devcontainer.json`; no new writable host mounts or baked secrets are added.
- Docker bits remain in the pinned base image; the feature only wires startup/entrypoint and does not introduce additional credential surfaces.

## Pinning and outage fallback

1. Resolve and pin a digest using `.github/workflows/pin-dind-feature.yml` (or the JSON from `bin/publish-dind-feature` / `publish-dind-feature.yml`), then set `DIND_FEATURE_REF="ghcr.io/technicalpickles/devcontainer-features/dind@sha256:<digest>"` when running `bin/apply` or replace the features block with the pinned digest snippet from `devcontainer.json`.
2. Retry with backoff using the pinned digest (`devcontainer up` / `bin/build`); avoid switching to `latest` during an outage.
3. If GHCR remains unavailable, temporarily vendor the feature files from `src/dotfiles/.devcontainer/features/dind/` with a clear cleanup reminder to remove them once registry access returns.
4. After recovery, restore the pinned GHCR reference, remove any vendored feature files from consuming repos, and record the digest + validation evidence in this document.

## Validation status

- v0.1.1: pending publish; use `publish-dind-feature.yml` for devcontainer packaging/tests and record digest from the JSON summary under `tmp/dind-feature-publish.json`.
- `publish-dind-feature.yml`: publishes via GHCR with devcontainer CLI packaging/tests + base-image Goss gate (pinned digest: `ghcr.io/technicalpickles/dotfiles-devcontainer/base@sha256:3195dd842e35bc1318b06c86c849e464b23fbc2082fc5de64f4b7bcaa789a63b`).
- `feature-publish.yaml`: pass (publishes v0.1.0, digest `sha256:30eeba4b20d48247dde11bbab5b813a4b3748dc34014bebec46bf28e8b658020`).
- `bats test/apply.bats`: pass (template references GHCR DinD and no vendored features).
- `test/features/dind/test.sh`: pass on GH Actions runner (installs feature locally, starts dockerd, verifies `docker info`); set `REQUIRE_DOCKER=true` when running in a base-image/devcontainer context that includes Docker engine bits.
- `bin/smoke-test --template dotfiles`: pass against base `ghcr.io/technicalpickles/dotfiles-devcontainer/base@sha256:3195dd842e35bc1318b06c86c849e464b23fbc2082fc5de64f4b7bcaa789a63b` (Docker 29.1.2; hello-world succeeds).

## Local validation

- Fast path: `bats test/apply.bats` (no Docker required).
- DinD wiring inside devcontainer (preferred): build/pull a base with dockerd, then:

  ```sh
  ./bin/build-base --tag local/dotfiles-devcontainer/base:test
  bin/smoke-test --base-image local/dotfiles-devcontainer/base:test
  ```

  This runs `test/features/dind/test.sh` inside the devcontainer with privileged Docker and the local feature source. Requires host Docker with privileged support.
- Direct host run of `test/features/dind/test.sh` needs a local dockerd; otherwise it will exit early with a missing Docker engine warning.
