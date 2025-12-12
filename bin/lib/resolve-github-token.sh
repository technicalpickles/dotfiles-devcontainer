#!/usr/bin/env bash
# Resolve GitHub token from various sources with priority ordering
#
# Priority:
# 1. $GITHUB_TOKEN if already set in environment
# 2. fnox get GITHUB_TOKEN if fnox is available
# 3. gh auth token as fallback
# 4. Error with helpful message if none available

resolve_github_token() {
	if [[ -n ${GITHUB_TOKEN:-} ]]; then
		echo "Using GITHUB_TOKEN from environment" >&2
		echo "$GITHUB_TOKEN"
		return 0
	fi

	if command -v fnox >/dev/null 2>&1; then
		if token=$(fnox get GITHUB_TOKEN 2>/dev/null) && [[ -n $token ]]; then
			echo "Resolved GITHUB_TOKEN via fnox" >&2
			echo "$token"
			return 0
		fi
	fi

	if command -v gh >/dev/null 2>&1; then
		if token=$(gh auth token 2>/dev/null) && [[ -n $token ]]; then
			echo "Resolved GITHUB_TOKEN via gh CLI" >&2
			echo "$token"
			return 0
		fi
	fi

	echo "Error: GITHUB_TOKEN not available. Try: gh auth login, fnox, or export GITHUB_TOKEN=..." >&2
	return 1
}
