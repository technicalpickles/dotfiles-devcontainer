# Pickled Dev Container

A [Dev Container Template](https://containers.dev/templates) that provides a pre-configured development environment with Josh's dotfiles ([pickles](https://github.com/technicalpickles/dotfiles)) pre-installed. This gives you a consistent development environment with your favorite shell, tools, and configurations ready to go.

## What is This?

This is a devcontainer template that:

- 🐚 **Installs Fish shell** with starship prompt
- 🔧 **Configures your dotfiles** from your personal repository
- 🛠️ **Pre-installs common tools** like gh (GitHub CLI), mise, tmux
- 🐳 **Includes Docker-in-Docker** for container workflows
- 🔐 **Integrates 1Password CLI** for secure credential management
- ⚙️ **Customizes VS Code** with your preferred extensions and settings

The template is designed to work with any project - it layers your personal development environment on top of any codebase.

## Quick Start

### Using in VS Code

1. **Install Prerequisites**:
   - [Docker Desktop](https://www.docker.com/products/docker-desktop)
   - [VS Code](https://code.visualstudio.com/)
   - [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

2. **Add to Your Project**:
   - Open your project in VS Code
   - Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
   - Select "Dev Containers: Add Dev Container Configuration Files..."
   - Choose "Add configuration to workspace"
   - Search for "Pickled Dev Environment" and select it
   - Configure your options:
     - **Role**: Choose `devcontainer`, `personal`, or `work`
     - **Dotfiles Repo**: URL to your dotfiles repository
     - **Dotfiles Branch**: Branch to use (usually `main`)

3. **Open in Container**:
   - Press `Cmd+Shift+P` / `Ctrl+Shift+P`
   - Select "Dev Containers: Reopen in Container"
   - Wait for the container to build and start

### Applying the Template with CLI

#### Quick Apply (Recommended)

Use the `bin/apply` helper script for the easiest setup:

```bash
# From this repository (if cloned locally)
cd /path/to/pickled-devcontainer
./bin/apply /path/to/your/project

# Or via curl (one-liner)
curl -fsSL https://raw.githubusercontent.com/technicalpickles/pickled-devcontainer/main/bin/apply | bash -s -- /path/to/your/project
```

The script automatically:
- Detects if running from the repo or standalone
- Installs `@devcontainers/cli` if needed (via npx or npm)
- Applies the template with your options
- Warns if `.devcontainer/` already exists

**Custom options:**
```bash
# Use custom dotfiles and role
./bin/apply \
  --role work \
  --repo https://github.com/YOUR_USERNAME/dotfiles.git \
  --branch main \
  /path/to/your/project

# Or with environment variables
ROLE=personal DOTFILES_REPO=https://github.com/me/dots.git ./bin/apply .
```

#### Manual CLI Application

You can also use the devcontainer CLI directly:

```bash
# Install the devcontainer CLI if you don't have it
npm install -g @devcontainers/cli

# Navigate to your project directory
cd /path/to/your/project

# Apply the template
devcontainer templates apply \
  --template-id ghcr.io/technicalpickles/pickled-devcontainer/pickles:latest \
  --template-args role=devcontainer \
  --template-args dotfilesRepo=https://github.com/technicalpickles/dotfiles.git \
  --template-args dotfilesBranch=main

# Build and start the container
devcontainer up --workspace-folder .
```

### Using Your Own Dotfiles

To use your own dotfiles instead of the defaults:

**Via VS Code**: Configure the options when adding the template to specify your repository URL and branch.

**Via bin/apply**: Use the `--repo` and `--branch` flags (shown in examples above).

**Via CLI**: Use the `--template-args` flag:
```bash
devcontainer templates apply \
  --template-id ghcr.io/technicalpickles/pickled-devcontainer/pickles:latest \
  --template-args role=personal \
  --template-args dotfilesRepo=https://github.com/YOUR_USERNAME/dotfiles.git \
  --template-args dotfilesBranch=main
```

## macOS Performance Optimization

Docker Desktop on macOS has poor performance with bind mounts (the default method where your local files are mounted into the container). For significantly better performance, **clone your repository directly into a Docker volume** using VS Code's built-in feature.

### Recommended: Clone Repository in Container Volume (Best for macOS)

This is the optimal workflow for macOS users to get maximum performance:

1. **Open VS Code** (without opening a folder first)
2. **Press** `Cmd+Shift+P`
3. **Select** "Dev Containers: Clone Repository in Container Volume..."
4. **Enter** your repository URL (e.g., `https://github.com/username/repo.git`)
5. **Choose a template**:
   - Select "Show All Definitions..."
   - Search for "Pickled Dev Environment"
   - Select it
6. **Configure** your dotfiles options:
   - **Role**: Choose `devcontainer`, `personal`, or `work`
   - **Dotfiles Repo**: Your dotfiles repository URL
   - **Dotfiles Branch**: Branch to use (usually `main`)
7. **Wait** for VS Code to:
   - Create a Docker volume
   - Clone your repository into the volume
   - Build the dev container with your configuration
   - Open your workspace

Your repository is now running in a Docker volume with native performance!

### Performance Comparison

| Method | Read/Write Speed | VS Code Experience |
|--------|------------------|-------------------|
| **Clone in Volume** (recommended) | Fast - native Docker speed | Seamless, no difference |
| **Bind Mount** (default) | 2-10x slower on macOS | Same experience but slower |

### Why This Works Better

- **No file system translation**: Docker doesn't need to translate between macOS and Linux file systems
- **Native Docker I/O**: Files live inside Docker's native storage
- **VS Code integration**: VS Code's remote extension handles everything seamlessly
- **Same experience**: You edit files directly in VS Code, no difference in workflow

### What About My Local Files?

With this approach:
- ✅ **Edit normally**: VS Code connects to the container, you edit files as usual
- ✅ **Git operations**: Work normally inside the container
- ✅ **Access your code**: Use VS Code's Explorer, terminal, etc. - everything works
- ⚠️ **Not on your Mac's filesystem**: Code lives in Docker volume, not `~/workspace`
- ⚠️ **Backup separately**: Use git push/pull to backup; volume is isolated

To access files outside VS Code if needed:
```bash
# List volumes
docker volume ls

# Copy files out
docker cp <container-id>:/workspaces/project ./local-backup
```

### Additional Performance Tips

1. **Allocate more resources** to Docker Desktop:
   - Open Docker Desktop → Settings → Resources
   - Increase CPUs to 4+ and Memory to 8GB+

2. **Enable VirtioFS** (if available):
   - Docker Desktop → Settings → General
   - Enable "VirtioFS for file sharing"

3. **Use .dockerignore** to exclude large directories:
   ```
   node_modules
   .git
   tmp
   *.log
   ```

## Template Options

| Option | Description | Default |
|--------|-------------|---------|
| `role` | Environment role for dotfiles configuration | `devcontainer` |
| `dotfilesRepo` | Git URL of your dotfiles repository | `https://github.com/technicalpickles/dotfiles.git` |
| `dotfilesBranch` | Branch to use from dotfiles repo | `main` |

The `role` option is passed to your dotfiles' `install.sh` script as the `DOTPICKLES_ROLE` environment variable, allowing you to customize installation based on context (personal vs work vs devcontainer).

## What's Included

### Base Tools
- Ubuntu base image
- Build essentials (gcc, make, etc.)
- Git, curl, wget, tmux
- Fish shell (set as default)
- Starship prompt
- GitHub CLI (gh)
- mise (runtime version manager)

### Dev Container Features
- Docker-in-Docker (for running containers inside the devcontainer)
- 1Password CLI integration

### VS Code Customizations
- Fish shell as default terminal
- Prettier extension pre-installed
- Configured terminal profiles

## Development Workflow

### Helper Scripts

This repository includes several helper scripts in the `bin/` directory:

**bin/apply** - Apply template to a project
```bash
# Apply to a project directory
./bin/apply /path/to/your/project

# With custom options
./bin/apply --role work --repo https://github.com/user/dots.git ~/project

# View all options
./bin/apply --help
```

**bin/build** - Build template for local testing
```bash
# Build the template with default options
./bin/build

# Build specific template
./bin/build pickles
```

**bin/run** - Run the built container
```bash
# Run tests or open shell in built container
./bin/run
```

**bin/stop** - Stop and clean up
```bash
# Stop container and cleanup
./bin/stop
```

### Project Structure

```
.
├── src/
│   └── pickles/                    # The template
│       ├── devcontainer-template.json  # Template metadata and options
│       └── .devcontainer/
│           ├── devcontainer.json   # Container configuration
│           ├── Dockerfile          # Container image definition
│           └── post-create.sh      # Post-creation setup script
├── test/
│   └── pickles/
│       └── test.sh                 # Template tests
├── bin/
│   ├── apply                       # Apply template to a project
│   ├── build                       # Build template for testing
│   ├── run                         # Run built container
│   └── stop                        # Stop and cleanup
└── README.md
```

## Publishing Updates

This template is published to GitHub Container Registry (GHCR) automatically via GitHub Actions when you push changes:

1. Make changes to files in `src/pickles/`
2. Commit and push to main
3. GitHub Actions builds and publishes to: `ghcr.io/technicalpickles/pickled-devcontainer/pickles:latest`

Users can then pull the latest version when they create or update their dev containers.

## Customization

### Extending the Dockerfile

Add additional tools by editing [src/pickles/.devcontainer/Dockerfile](src/pickles/.devcontainer/Dockerfile):

```dockerfile
# Add your custom tools
RUN apt-get update && apt-get install -y \
    your-package-here \
    && apt-get clean
```

### Adding VS Code Extensions

Edit [src/pickles/.devcontainer/devcontainer.json](src/pickles/.devcontainer/devcontainer.json):

```jsonc
{
  "customizations": {
    "vscode": {
      "extensions": [
        "esbenp.prettier-vscode",
        "your-extension-id-here"
      ]
    }
  }
}
```

### Customizing Post-Creation Steps

Edit [src/pickles/.devcontainer/post-create.sh](src/pickles/.devcontainer/post-create.sh) to add setup steps that run after the container is created:

```bash
#!/usr/bin/env bash
# Your custom setup steps here
```

## Troubleshooting

### Container Build Fails
- Check Docker Desktop is running
- Ensure you have enough disk space
- Try `docker system prune` to clean up old images

### Dotfiles Not Installing
- Verify your dotfiles repository URL is correct
- Check that your `install.sh` script is executable
- Look at container logs: `docker logs <container-id>`

### Slow Performance on macOS
- See [macOS Performance Optimization](#macos-performance-optimization) section above
- Consider using named volumes instead of bind mounts

### Permission Errors
- The container runs as the `vscode` user (non-root)
- Check file permissions if you see access denied errors
- Git safe.directory is configured automatically in post-create.sh

## Contributing

This is a personal template, but feel free to:
- Open issues for bugs or questions
- Submit PRs for improvements
- Fork and customize for your own needs

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Related Resources

- [Dev Container Templates Specification](https://containers.dev/implementors/templates)
- [Dev Containers Documentation](https://containers.dev/)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Pickles Dotfiles](https://github.com/technicalpickles/dotfiles)
