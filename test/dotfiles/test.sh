#!/bin/bash
cd "$(dirname "$0")" || exit 1
# shellcheck source=../test-utils/test-utils.sh disable=SC1091
source ../test-utils/test-utils.sh

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

# Report result
reportResults
