# Data Model: Multi-arch base image support

## Entities

- **BaseImageVariant**
  - Fields: `architecture` (ARM64 | X86/AMD64), `tag` (string), `digest` (string), `validation_status` (pending | passed | failed), `build_timestamp`, `source_ref` (branch/tag), `notes` (warnings/errors)
  - Relationships: belongs to one `ReleaseArtifactRecord`.
  - Validation: tag must be unique per architecture; digest must be recorded after successful build; validation_status must reflect smoke/Goss outcome.

- **ReleaseArtifactRecord**
  - Fields: `release_id` (string or version), `variants` (list of BaseImageVariant), `status` (complete | failed), `published_at`, `ci_run_id`.
  - Relationships: aggregates BaseImageVariant entries for a given release.
  - Validation: release status is complete only when all variants are present and passed validation; incomplete variants block publication.

- **ArchitectureSelection**
  - Fields: `detected_arch` (string), `requested_arch` (optional string override), `resolved_arch` (string), `warning` (optional message).
  - Relationships: used during devcontainer apply/build flows.
  - Validation: resolved_arch must match a published variant; warnings emitted when detected_arch is unsupported or mismatched.

## State Transitions

- **BaseImageVariant.validation_status**
  - `pending` → `passed` when smoke/Goss succeed.
  - `pending` → `failed` when validation fails; must block release.

- **ReleaseArtifactRecord.status**
  - `failed` when any required variant is missing or failed validation.
  - `complete` only when all required variants are present and passed.

## Rules from Requirements

- Both architectures must exist per release and be validated before publishing.
- Architecture resolution defaults to detected host but must support explicit override without editing base image definitions.
- Warnings must be surfaced when detected architecture is unsupported; no silent fallback to emulation or mismatched images.
