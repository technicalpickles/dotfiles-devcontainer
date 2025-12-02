#!/usr/bin/env bash
# Helper to materialize the simple dotfiles fixture as a temporary git repo.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
		git add . >/dev/null
		git commit -m "fixture" >/dev/null
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
