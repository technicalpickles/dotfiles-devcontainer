# VS Code Dev Container Templates — How They Work and How to Create Your Own

## Overview
VS Code **Dev Container Templates** are packaged configurations that define ready-to-use development environments. They include metadata, configuration files, and optional setup scripts. These templates can be published to registries (such as GHCR) and used to quickly scaffold reproducible environments in VS Code or via the Dev Container CLI.

---

## How Dev Container Templates Work

### Concept
- A **Template** contains a `devcontainer.json` and a `devcontainer-template.json` file.
- When a developer applies a template, the system copies these files into their workspace and replaces placeholders (e.g., `${templateOption:...}`) with user-provided values.
- Templates are distributed as OCI artifacts (e.g., `ghcr.io/org/repo/template:version`).

### Templates vs. Features
| Concept | Description |
|----------|--------------|
| **Templates** | Define a full environment setup — base image, features, settings, etc. |
| **Features** | Modular add-ons referenced inside a `devcontainer.json` to install extra tools. |

Templates often combine multiple features into one opinionated environment.

---

## Structure of a Template
A minimal template folder must include:

```
src/<template-name>/
│
├── devcontainer-template.json   # Metadata and user options
├── devcontainer.json            # Container definition
└── optional/                    # Optional supporting files
```

### Example: `devcontainer-template.json`
```json
{
  "id": "node",
  "version": "1.0.0",
  "name": "Node.js Workspace",
  "description": "Node.js dev environment with pnpm option",
  "publisher": "acme",
  "options": {
    "nodeVersion": {
      "type": "string",
      "description": "Node version",
      "proposals": ["20", "18", "16"],
      "default": "20"
    },
    "installPnpm": {
      "type": "boolean",
      "description": "Install pnpm feature",
      "default": true
    }
  }
}
```

### Example: `devcontainer.json`
```json
{
  "name": "Node",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:0-${templateOption:nodeVersion}",
  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "${templateOption:nodeVersion}" },
    "ghcr.io/devcontainers/features/pnpm:1": { "version": "latest" }
  }
}
```

---

## Step-by-Step: Creating Your Own Template

### 1. Scaffold
Start from the official starter repository:
```bash
git clone https://github.com/devcontainers/template-starter my-template
cd my-template
```

This repo includes a GitHub Actions workflow and folder layout for publishing.

### 2. Add Your Template Files
Inside `src/<your-template>/`, add your `devcontainer.json` and `devcontainer-template.json`. Define any `options` that users can customize.

### 3. Test Locally
Use the Dev Container CLI:
```bash
npm i -g @devcontainers/cli

devcontainer templates package ./src --output ./dist

mkdir -p /tmp/test-template && cd /tmp/test-template
devcontainer templates apply \
  --workspace-folder . \
  --template-id "file:///PATH/TO/my-template/dist/<id>.tgz" \
  --template-args '{"nodeVersion":"20","installPnpm":"true"}'
```

### 4. Publish
Push to GitHub Container Registry (GHCR):
```bash
echo $GHCR_TOKEN | docker login ghcr.io -u <user> --password-stdin
devcontainer templates publish ./src --registry ghcr.io/<org>/<repo>
```
Reference it later as:
```
ghcr.io/<org>/<repo>/<template>:<version>
```

### 5. Consume
In VS Code:
> **Command Palette → Dev Containers: Add Dev Container Configuration Files…**

Or via CLI:
```bash
devcontainer templates apply \
  --workspace-folder . \
  --template-id ghcr.io/<org>/<repo>/<template>:<version>
```

---

## Best Practices

- **Use semantic versioning** (`1.0.0`, `1.1.0`, etc.) and increment for breaking changes.
- Keep options minimal — sensible defaults make templates approachable.
- Use **Features** for add-ons rather than baking everything into the image.
- Mark sample files as optional via `optionalPaths`.
- Reference official templates (e.g., [devcontainers/templates](https://github.com/devcontainers/templates)) for inspiration.

---

## Summary
Dev Container Templates streamline environment setup by packaging complete configurations with user-tunable options. They’re easy to create, test, and publish — and integrate seamlessly into both VS Code and the Dev Container CLI. Start from the template-starter, define your metadata and configuration, and publish to GHCR for others to use.

