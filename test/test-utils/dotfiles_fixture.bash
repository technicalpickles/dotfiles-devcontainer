#!/usr/bin/env bash
# Helper to materialize the simple dotfiles fixture as a temporary git repo.

SCRIPT_PATH="${BASH_SOURCE[0]:-${0}}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" 2>/dev/null || pwd)"

find_repo_root() {
	local dir="${SCRIPT_DIR:-$(pwd)}"
	while [[ $dir != "/" ]]; do
		if [[ -d "$dir/.git" ]]; then
			echo "$dir"
			return 0
		fi
		dir="$(cd "$dir/.." 2>/dev/null || pwd)"
	done
	pwd
}

REPO_ROOT="$(find_repo_root)"
DOTFILES_FIXTURE_ROOT="${REPO_ROOT}/test/fixtures/simple-dotfiles"
DOTFILES_FIXTURE_DIRS=()

create_dotfiles_fixture_repo() {
	mkdir -p "${REPO_ROOT}/tmp"
	local dest="${1:-$(mktemp -d "${REPO_ROOT}/tmp/simple-dotfiles-XXXX")}"

	rm -rf "$dest"
	mkdir -p "$dest"
	cp -a "${DOTFILES_FIXTURE_ROOT}/." "$dest/"
	chmod +x "$dest/install.sh"

	(
		cd "$dest" || exit 1
		GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git -c core.fsmonitor=false init -b main >/dev/null
		GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.email "fixture@example.com"
		GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git config user.name "Fixture User"
		GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git add . >/dev/null
		GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git commit -m "fixture" >/dev/null
	)

	DOTFILES_FIXTURE_DIRS+=("$dest")
	echo "$dest"
}

cleanup_dotfiles_fixtures() {
	if [[ -n ${DOTFILES_FIXTURE_DIRS+x} && ${#DOTFILES_FIXTURE_DIRS[@]} -gt 0 ]]; then
		for dir in "${DOTFILES_FIXTURE_DIRS[@]}"; do
			rm -rf "$dir"
		done
		DOTFILES_FIXTURE_DIRS=()
	fi
}
