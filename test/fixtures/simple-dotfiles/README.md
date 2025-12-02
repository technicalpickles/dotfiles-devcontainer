# Simple dotfiles fixture for tests

This is a minimal dotfiles repo used by tests to avoid depending on personal dotfiles.

It provides:

- `install.sh` that writes a small Fish and Starship config into `~/.config`
- A sentinel file `.fixture-installed` to confirm the installer ran

Tests materialize this fixture as a temporary git repo so `setup-dotfiles` can clone it via a `file://` URL.
