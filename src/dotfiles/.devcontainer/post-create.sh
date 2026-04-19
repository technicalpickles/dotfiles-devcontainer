#!/usr/bin/env bash
set -euo pipefail

BASE_POST_CREATE="${BASE_POST_CREATE:-/usr/local/bin/devcontainer-post-create}"
# shellcheck disable=SC2154 # templateOption placeholders replaced by apply
export DOTFILES_REPO="${templateOption:dotfilesRepo}"
# shellcheck disable=SC2154 # templateOption placeholders replaced by apply
export DOTFILES_BRANCH="${templateOption:dotfilesBranch}"
# shellcheck disable=SC2154 # templateOption placeholders replaced by apply
export DOTFILES_INSTALL_ARGS_B64="${templateOption:dotfilesInstallArgsB64}"
export HOOK_ORDER="${HOOK_ORDER:-before}"

DEFAULT_HOOK_PATH="/workspace/.devcontainer/hooks/post-create"
if [[ ! -e $DEFAULT_HOOK_PATH ]]; then
	DEFAULT_HOOK_PATH="$(pwd)/.devcontainer/hooks/post-create"
fi
export HOOK_PATH="${HOOK_PATH:-${DEFAULT_HOOK_PATH}}"

echo "Delegating post-create to base entrypoint..."
echo "   DOTFILES_REPO=${DOTFILES_REPO}"
echo "   DOTFILES_BRANCH=${DOTFILES_BRANCH}"
echo "   DOTFILES_INSTALL_ARGS_B64=${DOTFILES_INSTALL_ARGS_B64}"
echo "   HOOK_ORDER=${HOOK_ORDER}"
echo "   HOOK_PATH=${HOOK_PATH}"

if [[ ! -x $BASE_POST_CREATE ]]; then
	echo "Expected base entrypoint at ${BASE_POST_CREATE}, but it is missing or not executable."
	echo "Ensure the base image includes devcontainer-post-create."
	exit 1
fi

"$BASE_POST_CREATE"
