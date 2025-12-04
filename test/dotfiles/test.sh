#!/bin/bash
cd "$(dirname "$0")" || exit 1
# shellcheck source=../test-utils/test-utils.sh disable=SC1091
source ../test-utils/test-utils.sh

wait_for_docker() {
	local attempts=30
	for _ in $(seq 1 "$attempts"); do
		if docker info >/dev/null 2>&1; then
			return 0
		fi
		sleep 1
	done
	return 1
}

# Template specific tests
unset DOTPICKLES_ROLE

check "distro" lsb_release -c
check "fish-installed" fish --version
check "starship-installed" starship --version
check "mise-installed" mise --version
check "gh-installed" gh --version
check "dotfiles-cloned" [ -d /home/vscode/.dotfiles ]
check "dotfiles-has-git" [ -d /home/vscode/.dotfiles/.git ]
check "default-shell-is-fish" [ "$(getent passwd vscode | cut -d: -f7)" = "/usr/bin/fish" ]
check "docker-cli-installed" docker --version
check "docker-daemon-ready" wait_for_docker
check "docker-run-hello-world" docker run --rm hello-world

# Report result
reportResults
