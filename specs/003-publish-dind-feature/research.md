# Research – Publish DinD Feature

## Publishing mechanism and registry namespace

Decision: Publish the Docker-in-Docker feature to GHCR under the existing namespace (e.g., `ghcr.io/technicalpickles/devcontainer-features/dind`) using the Devcontainer CLI `devcontainer features publish` workflow (pack + push) from GitHub Actions.
Rationale: GHCR aligns with the base image registry, supports scoped permissions, and integrates with devcontainer feature tooling for packaging and version tags/digests; GitHub Actions gives a repeatable, auditable pipeline.
Alternatives considered: Direct `docker buildx build/push` of the feature (would bypass devcontainer metadata handling); manual local publish (unrepeatable, harder to audit).

## Versioning and pinning strategy

Decision: Use semantic versions for feature publishes (e.g., `v0.1.0`) and reference a specific version (or digest when supported) in the template’s `features` block to keep consuming repos free of vendored assets while allowing controlled updates.
Rationale: Semver communicates change expectations, and explicit version/digest pins satisfy stability and outage recovery requirements without copying the feature.
Alternatives considered: Floating `latest` tag (breaks determinism); embedding feature files in the template (bloats consumers, violates spec intent).

## Template consumption and fallback for outages

Decision: Update the devcontainer template to consume the published feature by reference; document fallback steps: (1) retry pull, (2) temporarily switch to a pinned digest, (3) as a last resort, vendor a local copy with a clear cleanup note once registry access returns.
Rationale: Keeps consuming repos clean in steady state while giving users actionable guidance during registry interruptions.
Alternatives considered: Always vendor a copy in the template (contradicts goal); rely solely on retries without guidance (poor DX during outages).

## Testing and validation coverage

Decision: Validate publishes with `devcontainer features publish` built-in packaging/tests, run `bats test/apply.bats` to ensure template references resolve without local feature files, and keep base-image Goss smoke for Docker bits alignment.
Rationale: Ensures the feature packages correctly, the template wiring remains intact, and Docker components match expectations baked into the base image.
Alternatives considered: Ad-hoc manual testing (non-repeatable); skipping Goss/base checks (risks drift between feature wiring and baked Docker bits).

## Privileged Docker wiring alignment

Decision: Keep the feature focused on wiring (privileged container, mounts, entrypoint/env) and rely on the base image for Docker engine bits, ensuring the wiring matches the prebaked components documented in the base image.
Rationale: Prevents duplication, keeps feature lean, and honors the constitution’s requirement to reuse `setup-dotfiles` and the pinned base image.
Alternatives considered: Shipping Docker engine inside the feature (duplicates base image, slows pulls); loosening privileged requirements (breaks Docker-in-Docker functionality).
