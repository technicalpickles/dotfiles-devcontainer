#!/usr/bin/env bash
set -euo pipefail

echo "AWS CLI credentials mount configured via feature metadata."
# shellcheck disable=SC2016 # ${localEnv:HOME} is a devcontainer variable, not shell
echo 'Mount: ${localEnv:HOME}/.aws -> /home/vscode/.aws (read-only)'
echo "Note: AWS CLI must be installed separately (e.g., via base image or another feature)."
