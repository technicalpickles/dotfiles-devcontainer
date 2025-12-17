# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture & Principles

@ARCHITECTURE.md
@.specify/memory/constitution.md

## Common Commands

```bash
# Apply template to a project
./bin/apply ci-unpinned /path/to/project

# Test locally
./bin/smoke-test                    # Full smoke test
bats test/apply.bats                # Unit tests

# Base image
./bin/build-base && ./bin/test-base

# Publish features
./bin/publish-feature dind
./bin/publish-feature aws-cli
```

## Code Patterns

All bash scripts use `set -euo pipefail`. Template variables use `${templateOption:name}` syntax.
