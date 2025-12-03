#!/usr/bin/env bash
set -euo pipefail

REQUIRE_DOCKER="${REQUIRE_DOCKER:-false}"

echo "✓ verifying Docker engine binaries are present"
if ! command -v dockerd >/dev/null 2>&1; then
	if [[ $REQUIRE_DOCKER == "true" ]]; then
		echo "Docker engine (dockerd) not found; base image must include Docker bits for DinD feature" >&2
		exit 1
	fi
	echo "⚠️  dockerd not available in this environment; skipping DinD wiring check (set REQUIRE_DOCKER=true to enforce)" >&2
	exit 0
fi

echo "✓ starting dockerd via feature entrypoint"
/usr/local/share/dind/start-dind.sh true

echo "✓ verifying docker info succeeds"
DOCKER_HOST="unix:///var/run/docker.sock" docker info >/dev/null 2>&1 || {
	echo "docker info failed after starting dockerd" >&2
	exit 1
}

echo "✓ DinD feature validation completed"
