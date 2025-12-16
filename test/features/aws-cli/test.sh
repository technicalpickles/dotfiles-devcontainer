#!/usr/bin/env bash
# Validate aws-cli feature tarball packaging and metadata.
set -euo pipefail

FEATURE_SOURCE="${FEATURE_SOURCE:-./src/dotfiles/.devcontainer/features/aws-cli}"
FEATURE_TARBALL="${FEATURE_TARBALL:-}"
FEATURE_VERSION="${FEATURE_VERSION:-}"
TMP_FEATURE_DIR=""

cleanup() {
	if [[ -n $TMP_FEATURE_DIR && -d $TMP_FEATURE_DIR ]]; then
		rm -rf "$TMP_FEATURE_DIR"
	fi
}
trap cleanup EXIT

if [[ -n $FEATURE_TARBALL ]]; then
	TMP_FEATURE_DIR="$(mktemp -d)"
	echo "Extracting feature tarball ${FEATURE_TARBALL}"
	tar -xf "$FEATURE_TARBALL" -C "$TMP_FEATURE_DIR"
	found_json="$(find "$TMP_FEATURE_DIR" -type f -name devcontainer-feature.json | head -n 1 || true)"
	if [[ -z $found_json ]]; then
		echo "Unable to locate devcontainer-feature.json inside ${FEATURE_TARBALL}" >&2
		exit 1
	fi
	FEATURE_SOURCE="$(cd "$(dirname "$found_json")" && pwd)"
	echo "Tarball contains valid feature structure"
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

echo "Validating aws-cli feature ${FEATURE_VERSION} from ${FEATURE_SOURCE}"

# Validate feature metadata
node - "$FEATURE_SOURCE/devcontainer-feature.json" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const feature = JSON.parse(fs.readFileSync(file, 'utf8'));

const errors = [];

if (feature.id !== 'aws-cli') {
  errors.push(`Feature id should be 'aws-cli', got: ${feature.id}`);
}

const mounts = feature.mounts || [];
const hasAwsMount = mounts.some(m => {
  const mountStr = typeof m === 'string' ? m : JSON.stringify(m);
  return mountStr.includes('.aws') && mountStr.includes('/home/vscode/.aws');
});
if (!hasAwsMount) {
  errors.push('Feature must include ~/.aws mount to /home/vscode/.aws');
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}

console.log('Feature metadata valid');
NODE

echo "aws-cli feature validation completed"
