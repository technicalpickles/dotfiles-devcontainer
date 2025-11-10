# Dotfiles Repository Auto-Detection Design

**Date:** 2025-11-10
**Status:** Approved for Implementation

## Overview

Add intelligent auto-detection of the user's dotfiles repository to `bin/apply`, eliminating the need to manually specify `--repo` in most cases. The system gathers information from multiple sources, applies heuristics to choose the best option, and provides clear feedback about what was detected.

## Goals

1. **Zero-configuration UX** - Most users should be able to run `./bin/apply .` without any flags
2. **Multi-source intelligence** - Use all available information (env vars, git config, local repos, gh auth)
3. **Clear feedback** - Show what was detected and why, warn about inconsistencies
4. **Explicit override** - Always respect `--repo` flag or `$DOTFILES_REPO` env var

## Architecture

### Data Collection Phase

The `detect_dotfiles_repo()` function collects information from these sources in parallel:

1. **Environment variable** - `$DOTFILES_REPO` (if set at script invocation)
2. **Git config** - `git config github.user` → construct `https://github.com/{user}/dotfiles.git`
3. **Local dotfiles paths** - Check `~/dotfiles` and `~/.dotfiles`:
   - Verify it's a git repository
   - Extract remote URL: `git config --get remote.origin.url`
   - Normalize SSH URLs to HTTPS format
4. **GitHub CLI** - `gh auth status` to get authenticated username

**Data storage:**
```bash
DETECTED_REPO_ENV=""        # From $DOTFILES_REPO
DETECTED_REPO_GITCONFIG=""  # From git config github.user
DETECTED_REPO_LOCAL=""      # From local dotfiles directory
DETECTED_USER_GH=""         # From gh auth status
```

### Decision Heuristics

After collecting all data, apply these rules in order:

1. **Explicit override wins**
   - If `$DOTFILES_REPO` was set or `--repo` used, use it immediately
   - Mark as `DOTFILES_REPO_EXPLICIT=true` to skip detection

2. **Cross-validation for consistency**
   - If `DETECTED_REPO_LOCAL` matches `DETECTED_REPO_GITCONFIG` → high confidence
   - If `DETECTED_USER_GH` username appears in any detected repo URL → validate
   - If multiple sources point to different repos → flag inconsistency

3. **Priority when inconsistent**
   - Authenticated (`DETECTED_USER_GH`) > git config > local repo
   - Rationale: `gh auth` proves access, git config is configuration, local might be stale

4. **Fallback chain**
   - Try validated/consistent source first
   - If none: `DETECTED_USER_GH` → `DETECTED_REPO_GITCONFIG` → `DETECTED_REPO_LOCAL`
   - Finally: template default (`https://github.com/technicalpickles/dotfiles.git`)

### Integration Point

Call `detect_dotfiles_repo()` after argument parsing but before using `$DOTFILES_REPO`:

```bash
# After argument parsing (around line 107 in bin/apply)

# Track if repo was explicitly set
if [[ -n "${DOTFILES_REPO:-}" && "$DOTFILES_REPO" != "https://github.com/technicalpickles/dotfiles.git" ]]; then
  DOTFILES_REPO_EXPLICIT=true
fi

# Auto-detect if not explicit
if [[ "${DOTFILES_REPO_EXPLICIT:-false}" == "false" ]]; then
  detect_dotfiles_repo
fi

# Continue with existing logic...
```

**Command-line flag handling:**
- When `--repo` is used, set `DOTFILES_REPO_EXPLICIT=true` before detection runs
- When `$DOTFILES_REPO` env var differs from template default, set `DOTFILES_REPO_EXPLICIT=true`

## Output Examples

### Success - Single Source
```
🔍 Auto-detecting dotfiles repository...
   ✓ Found via git config: https://github.com/technicalpickles/dotfiles.git
   Using: https://github.com/technicalpickles/dotfiles.git
```

### Success - Validated Consistency
```
🔍 Auto-detecting dotfiles repository...
   ✓ Found via git config: https://github.com/technicalpickles/dotfiles.git
   ✓ Validated: Local ~/dotfiles matches git config
   Using: https://github.com/technicalpickles/dotfiles.git
```

### Warning - Inconsistency
```
🔍 Auto-detecting dotfiles repository...
   ⚠️  Multiple dotfiles repos detected:
       - git config: https://github.com/technicalpickles/dotfiles.git
       - local ~/dotfiles: https://github.com/olduser/dotfiles.git
   Using authenticated source: https://github.com/technicalpickles/dotfiles.git
   (Set $DOTFILES_REPO or use --repo to override)
```

### Explicit Override
```
🔍 Using explicitly specified dotfiles repository
   Repo: https://github.com/myuser/my-dotfiles.git
```

## Error Handling

### Silent Failures (Graceful Degradation)
- `gh` not installed → skip GitHub CLI detection
- Local paths don't exist → skip local detection
- `git config github.user` not set → skip git config detection
- Commands fail (non-zero exit) → skip that source

### Validation Warnings
- Constructed URL looks suspicious (no repo name, invalid format) → warn but continue
- SSH URL normalization fails → use URL as-is with warning

### Detection Failure
- No sources found → use template default silently (current behavior)
- Same UX as before if nothing is configured

### Verbose Mode
Add `--verbose` flag to show detection details:
```bash
./bin/apply --verbose .
```

Output includes:
- Each source checked and result
- Why each source was chosen/rejected
- Cross-validation logic decisions

## Edge Cases

| Scenario | Handling |
|----------|----------|
| SSH URLs | Normalize to HTTPS: `git@github.com:user/repo.git` → `https://github.com/user/dotfiles.git` |
| Non-GitHub remotes | Use as-is (GitLab, Bitbucket, self-hosted) |
| Multiple local dotfiles | Prefer `~/dotfiles` over `~/.dotfiles` |
| Empty git config | Skip that source silently |
| Username mismatch | Warn but allow (might be org repo or fork) |
| Invalid URLs | Validate basic format, warn if suspicious |

## URL Normalization

Convert SSH format to HTTPS for consistency:

```bash
# Input: git@github.com:technicalpickles/dotfiles.git
# Output: https://github.com/technicalpickles/dotfiles.git

normalize_git_url() {
  local url="$1"
  # Convert SSH to HTTPS
  if [[ "$url" =~ ^git@([^:]+):(.+)$ ]]; then
    echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    echo "$url"
  fi
}
```

## Testing Strategy

### Unit Test Scenarios
1. **Single source tests:**
   - Only env var set
   - Only git config set
   - Only local repo exists
   - Only gh auth available

2. **Consistency tests:**
   - Git config matches local repo
   - gh auth matches git config
   - All three match

3. **Conflict tests:**
   - Git config vs local repo mismatch
   - gh auth vs git config mismatch
   - Three-way conflict

4. **Edge cases:**
   - SSH URL normalization
   - Non-GitHub URLs
   - Invalid/empty values
   - Missing tools (no gh, no git config)

5. **Override tests:**
   - `--repo` flag overrides all detection
   - `$DOTFILES_REPO` env var overrides detection
   - Template default used when nothing found

### Manual Testing
- Test on fresh machine with no configuration
- Test with various combinations of sources
- Test with `--verbose` to verify output
- Test with explicit overrides

## Implementation Notes

### Function Signature
```bash
detect_dotfiles_repo() {
  # Sets $DOTFILES_REPO based on detected sources
  # Prints detection information to stdout
  # Returns 0 on success, 0 on fallback to default
}
```

### Failure Mode
All detection failures are non-fatal. The function always succeeds and falls back to the template default if nothing is found.

### Performance
- All checks run in sequence (not parallel to avoid complexity)
- Total overhead: ~100-200ms on typical systems
- Most time spent on `gh auth status` if installed (network call)

## Future Enhancements

**Out of scope for initial implementation:**

1. **Branch detection** - Also detect preferred branch from local repo
2. **Repo verification** - Actually test if repo exists (requires network call)
3. **Interactive mode** - Ask user to choose when conflicts detected
4. **Cache** - Remember choice for subsequent runs
5. **Configuration file** - `~/.config/dotfiles-devcontainer/config`

These can be added in future iterations based on user feedback.
