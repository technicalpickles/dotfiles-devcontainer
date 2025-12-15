#!/usr/bin/env bash
# Validate DinD feature tarball packaging and publish metadata.
# Runtime validation (docker daemon, containers) is handled by goss tests.
set -euo pipefail

FEATURE_SOURCE="${FEATURE_SOURCE:-./src/dotfiles/.devcontainer/features/dind}"
FEATURE_TARBALL="${FEATURE_TARBALL:-}"
FEATURE_VERSION="${FEATURE_VERSION:-}"
FEATURE_DIGEST="${FEATURE_DIGEST:-}"
PUBLISH_RESULT_PATH="${PUBLISH_RESULT_PATH:-}"
PUBLISH_RESULT_JSON="${PUBLISH_RESULT_JSON:-}"
TMP_FEATURE_DIR=""
TMP_PUBLISH_FILE=""

cleanup() {
	if [[ -n $TMP_FEATURE_DIR && -d $TMP_FEATURE_DIR ]]; then
		rm -rf "$TMP_FEATURE_DIR"
	fi
	if [[ -n $TMP_PUBLISH_FILE && -f $TMP_PUBLISH_FILE ]]; then
		rm -f "$TMP_PUBLISH_FILE"
	fi
}
trap cleanup EXIT

if [[ -n $FEATURE_TARBALL ]]; then
	TMP_FEATURE_DIR="$(mktemp -d)"
	echo "✓ extracting feature tarball ${FEATURE_TARBALL}"
	tar -xf "$FEATURE_TARBALL" -C "$TMP_FEATURE_DIR"
	found_json="$(find "$TMP_FEATURE_DIR" -type f -name devcontainer-feature.json | head -n 1 || true)"
	if [[ -z $found_json ]]; then
		echo "Unable to locate devcontainer-feature.json inside ${FEATURE_TARBALL}" >&2
		exit 1
	fi
	FEATURE_SOURCE="$(cd "$(dirname "$found_json")" && pwd)"
	echo "✓ tarball contains valid feature structure"
elif [[ -d $FEATURE_SOURCE ]]; then
	FEATURE_SOURCE="$(cd "$FEATURE_SOURCE" && pwd)"
else
	echo "FEATURE_SOURCE does not exist: ${FEATURE_SOURCE}" >&2
	exit 1
fi

if [[ ! -f "$FEATURE_SOURCE/devcontainer-feature.json" ]]; then
	echo "devcontainer-feature.json not found under ${FEATURE_SOURCE}" >&2
	exit 1
fi

if [[ -z $FEATURE_VERSION ]]; then
	FEATURE_VERSION="$(node -e "console.log(require(process.argv[1]).version || '')" "$FEATURE_SOURCE/devcontainer-feature.json")"
fi

display_ref="$FEATURE_VERSION"
if [[ -n $FEATURE_DIGEST ]]; then
	display_ref="${display_ref}@${FEATURE_DIGEST}"
fi

validate_publish_summary() {
	local publish_file=""
	if [[ -n $PUBLISH_RESULT_PATH && -f $PUBLISH_RESULT_PATH ]]; then
		publish_file="$PUBLISH_RESULT_PATH"
	elif [[ -n $PUBLISH_RESULT_JSON ]]; then
		TMP_PUBLISH_FILE="$(mktemp)"
		printf '%s\n' "$PUBLISH_RESULT_JSON" >"$TMP_PUBLISH_FILE"
		publish_file="$TMP_PUBLISH_FILE"
	fi

	if [[ -z $publish_file ]]; then
		echo "⚠️  No publish metadata provided; skipping publish validation"
		return 0
	fi

	echo "✓ validating publish metadata"

	node - "$publish_file" "$FEATURE_VERSION" <<'NODE'
const fs = require('fs');
const [file, expectedVersion] = process.argv.slice(2);
const data = JSON.parse(fs.readFileSync(file, 'utf8'));
const semver = /^v?\d+\.\d+\.\d+$/;
const normalize = (v) => (v || '').replace(/^v/, '');

const errors = [];
if (!semver.test(data.version)) {
  errors.push(`Invalid semver version in publish output: ${data.version}`);
} else if (expectedVersion && normalize(data.version) !== normalize(expectedVersion)) {
  errors.push(`Publish version ${data.version} does not match feature version ${expectedVersion}`);
}

if (!data.registryRef || !String(data.registryRef).includes('ghcr.io/technicalpickles/devcontainer-features/dind')) {
  errors.push(`Registry ref missing or incorrect: ${data.registryRef}`);
}

if (data.digest && String(data.digest).startsWith('sha256:') === false && data.digest !== '(dry-run)') {
  errors.push(`Digest missing or invalid: ${data.digest}`);
}

if (data.privileged !== true) {
  errors.push(`Publish metadata missing privileged=true (got ${data.privileged})`);
}

const entrypoint = data.entrypoint || '';
if (!entrypoint.includes('start-dind.sh')) {
  errors.push(`Entrypoint missing start-dind.sh: ${entrypoint}`);
}

const mounts = Array.isArray(data.mounts) ? data.mounts : [];
const requiredTargets = ['/var/lib/docker', '/var/log', '/run'];
for (const target of requiredTargets) {
  const matches = mounts.some((m) => String(m).includes(`target=${target}`));
  if (!matches) {
    errors.push(`Publish metadata missing mount target ${target}`);
  }
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}
NODE
}

echo "✓ validating DinD feature ${display_ref} from ${FEATURE_SOURCE}"

validate_publish_summary

echo "✓ DinD feature validation completed"
