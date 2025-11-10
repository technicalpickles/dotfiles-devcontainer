#!/bin/bash
cd $(dirname "$0")
source test-utils.sh

# Template specific tests
check "distro" lsb_release -c
check "fish-installed" fish --version
check "starship-installed" starship --version
check "mise-installed" mise --version
check "gh-installed" gh --version
check "dotfiles-cloned" [ -d /home/vscode/.pickles ]
check "dotfiles-has-git" [ -d /home/vscode/.pickles/.git ]
check "fish-config-exists" [ -f /home/vscode/.config/fish/config.fish ]
check "starship-config-exists" [ -f /home/vscode/.config/starship.toml ]
check "default-shell-is-fish" [ "$(getent passwd vscode | cut -d: -f7)" = "/usr/bin/fish" ]

# Report result
reportResults
