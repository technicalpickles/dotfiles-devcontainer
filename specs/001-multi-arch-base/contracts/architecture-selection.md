# Contract: Architecture selection and release gating

## Devcontainer apply/build UX (script contract)

- **Inputs**: base image tag (required), optional platform override (ARM64 | X86/AMD64).
- **Detection**: script reads host architecture; if override provided, use override; otherwise use detected_arch.
- **Validation**: resolved_arch must correspond to a published variant; if unsupported or unknown, emit warning and stop with actionable guidance (do not silently fall back).
- **Outputs**: selected image reference (tag + arch-aware digest when available); warnings when Docker reports platform mismatch.

## Release pipeline contract (GitHub Actions)

- **Inputs**: source ref (branch/tag), base image Dockerfile/context, target architectures [ARM64, X86/AMD64].
- **Build**: Docker Buildx builds both architectures on public runners; push manifests and per-arch digests to registry.
- **Validation**: run smoke/Goss for each architecture; failure blocks publication.
- **Outputs**: published images tagged per release with both architectures; release status marked failed if any variant fails validation.
