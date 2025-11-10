# Design Principles: Dotfiles Devcontainer Template

This document captures the design principles and architectural decisions made while creating this devcontainer template.

## Core Philosophy

### 1. **Clone from Upstream, Don't Copy**
**Decision:** Clone dotfiles from the upstream repository during build rather than copying the entire repo into the template.

**Rationale:**
- **Maintainability**: Template stays lightweight and doesn't duplicate dotfiles content
- **Single Source of Truth**: Dotfiles repo remains the authoritative source
- **Version Control**: Easy to specify branches/tags for different environments
- **Size**: Template artifact remains small for faster distribution

**Implementation:**
```dockerfile
ARG DOTFILES_REPO=https://github.com/YOUR_USERNAME/dotfiles.git
ARG DOTFILES_BRANCH=main
RUN git clone --branch ${DOTFILES_BRANCH} ${DOTFILES_REPO} /home/vscode/.dotfiles
```

**Template Options:**
```json
{
  "dotfilesRepo": {
    "type": "string",
    "description": "Dotfiles repository URL",
    "default": "https://github.com/YOUR_USERNAME/dotfiles.git"
  },
  "dotfilesBranch": {
    "type": "string",
    "description": "Dotfiles repository branch",
    "default": "main"
  },
  "installEnvVars": {
    "type": "object",
    "description": "Environment variables to set before running install.sh",
    "default": {}
  }
}
```

### 2. **Two-Phase Installation: Build-Time + Post-Create**
**Decision:** Run dotfiles installer during Docker build AND in post-create hook.

**Rationale:**
- **Build-Time**: Bakes core configuration into the image for faster container startup
- **Post-Create**: Allows for updates and environment-specific configuration
- **Caching**: Docker layer caching speeds up rebuilds when dotfiles haven't changed
- **Flexibility**: Post-create can pull latest changes without rebuilding image

**Implementation:**
```dockerfile
# Build-time: Bake dotfiles into image
RUN cd /home/vscode/.dotfiles && bash install.sh
```

```bash
# Post-create: Update and re-run
echo "📦 Updating dotfiles to latest..."
cd /home/vscode/.dotfiles
git pull
bash install.sh
```

### 3. **Local `tmp/` Directory for Build Artifacts**
**Decision:** Use repository-local `tmp/` directory instead of `/tmp/` for template builds.

**Rationale:**
- **Inspectability**: Easy to examine built templates without navigating system directories
- **Cleanup Control**: Can `.gitignore` but still inspect when needed
- **Isolation**: Multiple templates can be built concurrently without conflicts
- **Debugging**: Failed builds leave artifacts in a predictable location

**Implementation:**
```bash
SRC_DIR="$REPO_ROOT/tmp/${TEMPLATE_ID}"
```

```gitignore
tmp/
```

### 4. **Test-Oriented Build Scripts**
**Decision:** Build scripts (`bin/build`, `bin/run`, `bin/stop`) mimic GitHub Actions workflow for local testing.

**Rationale:**
- **Consistency**: Local testing matches CI behavior
- **Fast Iteration**: Test templates without pushing to registry
- **Template Processing**: Handles `${templateOption:...}` substitution locally
- **Debugging**: Run and inspect containers before publishing

**Implementation:**
```bash
# Copies template, processes options, builds with devcontainer CLI
bin/build [template-id]

# Executes tests or commands in built container
bin/run [template-id] [command]

# Cleans up container and optionally build directory
bin/stop [template-id] --clean
```

### 5. **Template Options as Build Args**
**Decision:** Make key configuration options templatable via `devcontainer-template.json`.

**Rationale:**
- **Reusability**: Same template works for different roles (personal/work/devcontainer)
- **Customization**: Users can specify their own dotfiles repo
- **Flexibility**: Branch selection allows testing experimental configurations

**Implementation:**
```json
{
  "options": {
    "installEnvVars": {
      "type": "object",
      "description": "Environment variables to set before running install.sh",
      "default": {},
      "additionalProperties": {
        "type": "string"
      }
    }
  }
}
```

These variables are passed to the container runtime via `containerEnv` and are available to your dotfiles `install.sh` script.

### 6. **Graceful Degradation**
**Decision:** Design for failures to be non-fatal where possible.

**Rationale:**
- **Private Submodules**: Some git submodules may be private (cheatsheets)
- **Optional Components**: Not every tool needs to succeed for environment to be usable
- **Network Issues**: Transient failures shouldn't block entire build

**Implementation:**
```bash
# In install.sh
git submodule update || {
  echo "Warning: Some submodules failed to initialize (this is non-fatal)"
  true # Ensure we don't exit with error code
}
```

## Architecture Patterns

### Repository Structure
```
dotfiles-devcontainer/
├── src/
│   └── dotfiles/                     # Template definition
│       ├── devcontainer-template.json
│       └── .devcontainer/
│           ├── devcontainer.json     # Devcontainer configuration
│           ├── Dockerfile            # Image definition
│           └── post-create.sh        # Post-creation hook
├── test/
│   └── dotfiles/
│       └── test.sh                   # Validation tests
├── bin/
│   ├── apply                         # Apply template to a project
│   ├── build                         # Build template locally
│   ├── run                           # Execute tests/commands
│   └── stop                          # Clean up
└── tmp/                              # Build artifacts (gitignored)
```

### Dockerfile Layering Strategy
```dockerfile
# Layer 1: Base system packages (rarely changes)
RUN apt-get install build-essential curl git...

# Layer 2: Shell installation (moderate frequency)
RUN apt-get install fish

# Layer 3: CLI tools (moderate frequency)
RUN install gh, mise, starship...

# Layer 4: Dotfiles clone (changes with each dotfiles update)
RUN git clone ${DOTFILES_REPO} ~/.dotfiles

# Layer 5: Dotfiles installation (changes with dotfiles)
RUN cd ~/.dotfiles && bash install.sh
```

**Rationale:** Most-stable layers first for maximum cache reuse.

## Reference Documentation

### Key Documents Consulted
1. **[VS Code Dev Container Templates — How They Work](vscode_devcontainer_templates.md)**
   - Template structure and metadata format
   - Option placeholders: `${templateOption:...}`
   - Publishing to GHCR workflow

2. **[Dev Container Git Repository State Reference](devcontainers_git_reference.md)**
   - Bind mount vs named volume tradeoffs
   - Performance implications on macOS
   - Git synchronization strategies

### Testing Workflow
Based on `.github/workflows/test-pr.yaml` and smoke-test scripts:

1. **Template Preparation**
   - Copy template to temporary location
   - Replace `${templateOption:...}` with defaults
   - Copy test files into build context

2. **Container Build**
   - Use `devcontainer up` with `--id-label` for identification
   - Build with template options as build args

3. **Test Execution**
   - Use `devcontainer exec` to run test.sh inside container
   - Validate tools, configuration, and environment

4. **Cleanup**
   - Remove container by label
   - Clean build directory

## Lessons Learned

### 1. **sed Portability**
macOS `sed` requires empty string for in-place edits: `sed -i ''`
Linux `sed` uses: `sed -i`

**Solution:** Use macOS syntax in build script (runs on macOS during development).

### 2. **Directory Creation**
Build script must create `tmp/` directory before copying template:
```bash
mkdir -p "$REPO_ROOT/tmp"
```

### 3. **Post-Create Failures are Soft**
Post-create hook failures don't prevent container from starting in dev mode.
Image successfully builds even if post-create fails.

### 4. **Dotfiles Install.sh is Environment-Aware**
The install script can use environment variables for customization:
- Detect and skip platform-specific tools (e.g., Homebrew on Linux)
- Differentiate between codespaces vs devcontainer contexts
- Use custom environment variables passed via `installEnvVars` option

## Future Considerations

### Potential Enhancements
1. **Multi-stage Dockerfile**: Separate build and runtime stages
2. **Feature Extraction**: Convert dotfiles setup to standalone devcontainer feature
3. **Caching Strategy**: Pre-build and publish images to GHCR for faster startup
4. **Test Matrix**: Test multiple option combinations in CI

### Open Questions
1. Should post-create be optional via template option?
2. Should we support local dotfiles path for development?
3. How to handle private dotfiles repositories?

## Summary

This template demonstrates a **reference-by-URL** pattern where dotfiles are cloned from upstream rather than embedded. This keeps the template lightweight, maintainable, and allows for version-controlled dotfiles management while providing a reproducible development environment through devcontainers.

The two-phase installation (build-time + post-create) balances image caching efficiency with runtime flexibility, while the local build scripts enable rapid iteration without needing to publish templates to a registry.
