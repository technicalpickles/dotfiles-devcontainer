#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-/home/vscode}"

mkdir -p "${HOME_DIR}/.config/fish" "${HOME_DIR}/.config"

cat >"${HOME_DIR}/.config/fish/config.fish" <<'EOF'
# Fixture Fish config used in tests
set -gx FIXTURE_FISH_LOADED 1
EOF

cat >"${HOME_DIR}/.config/starship.toml" <<'EOF'
[character]
success_symbol = ">"
error_symbol = ">"
EOF

# Marker to assert install.sh executed
echo "installed=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >"${ROOT_DIR}/.fixture-installed"
