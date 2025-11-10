# Dev Container Git Repository State Reference (macOS, Colima, and Named Volumes)

## Overview
When developing inside a VS Code **Dev Container** on macOS using **Colima** or another Docker runtime, there are two distinct ways to mount or host source code within the container:

1. **Bind mount (default)** — your local repository folder is mounted directly into the container.
2. **Named volume** — the repository is cloned into a persistent Docker volume using the *Clone Repository in Container Volume* workflow.

Each approach has implications for performance, Git behavior, and synchronization between host and container copies of the repository. This document provides an exhaustive reference for managing and understanding those differences.

---

## 1. Bind Mount (Default Mode)

### Description
By default, VS Code’s Dev Containers extension mounts the host folder directly into the container:
```json
"workspaceMount": "source=${localWorkspaceFolder},target=/workspaces/${localWorkspaceFolderBasename},type=bind"
```
This allows the container to operate directly on the host filesystem.

### Pros
- No duplication — same files visible to both host and container.
- Git state always matches host repository.
- Simple workflow for commits and pushes.

### Cons
- On macOS, bind-mounted volumes use **VirtioFS** or similar file sharing layers that introduce **high I/O latency**, making operations like `npm install`, `yarn build`, and large Git operations significantly slower.
- Permissions mismatches between macOS and containerized Linux may cause issues with `node_modules` or generated artifacts.

### Recommendations
- Use for lightweight edits or when filesystem performance is acceptable.
- Avoid for large repos or heavy I/O workloads.
- Prefer Colima’s VirtioFS configuration for minimal slowdown.

---

## 2. Named Volume (Clone-in-Container Mode)

### Description
Running **Dev Containers → Clone Repository in Container Volume** creates a Docker named volume and clones the Git repository into it. This avoids host file‑sharing altogether.

```bash
docker volume create devcontainer-myproject
```

### Pros
- **Near‑native performance** for Linux containers on macOS (no bind mount overhead).
- Completely isolated from host filesystem — ideal for testing, clean builds, or PR reviews.
- Persistent across container rebuilds unless the volume is explicitly deleted.

### Cons
- Two separate Git working copies (host vs. container) — changes do not automatically sync.
- Can accumulate stale code if the volume is reused across container rebuilds.
- Must manually manage sync via `git push`/`git pull` between clones.
- Volume deletion is required for a truly fresh clone.

### Git Behavior Details
- A **new clone** is performed inside the volume; `.git` history, branches, and remotes match the source repository at clone time.
- Local branches or uncommitted changes on the host are not visible inside the container.
- To refresh the code, you must either `git pull` or delete the volume and re‑clone.
- Submodules are **not cloned automatically**; use a `postCreateCommand` in `devcontainer.json`:
  ```json
  "postCreateCommand": "git submodule update --init --recursive"
  ```

### Credential Handling
- The Dev Containers extension copies the host `.gitconfig` into the container.
- SSH agent or credential helpers can be forwarded via `mounts` or environment configuration:
  ```json
  "mounts": ["source=${env:SSH_AUTH_SOCK},target=/ssh-agent,type=bind"]
  ```
- On macOS, ensure your SSH key agent is running and forwarded properly; otherwise `git clone` or `git push` will fail.

---

## 3. Synchronization and Lifecycle Considerations

### Git Sync Scenarios
| Scenario | Description | Action Required |
|-----------|--------------|-----------------|
| Host commits ahead of container | Container still has older clone | Run `git pull` inside container |
| Container commits ahead of host | Host unaware of new work | Push to remote, then pull on host |
| Volume reused after rebuild | Old code remains | Delete volume (`docker volume rm …`) |
| Switching branches on host | Container clone unaffected | Check out same branch manually |

### Data Persistence
Named volumes survive container deletion until explicitly pruned:
```bash
docker volume ls
docker volume rm devcontainer-myproject
```
They are **not backups** — deleting a volume erases unpushed work.

### Backups & Remote Sync
Always push committed work to a remote repository (GitHub, GitLab, etc.) or manually export changes before deleting the volume.

---

## 4. Performance Implications
- Named volumes bypass macOS file‑sharing, yielding **10–100× faster I/O** for dependency installation, compilation, and file enumeration.
- Large repositories with many small files (e.g., Node.js or Rust projects) benefit the most.
- Bind mounts may still be acceptable for light editing or smaller projects.

---

## 5. Recommended Configuration Patterns

### 5.1 Clone in Volume via VS Code Command
- Use **Dev Containers → Clone Repository in Container Volume…** for the initial setup.
- Reopen in container using that volume when prompted.

### 5.2 Custom Volume Mount in `devcontainer.json`
```json
{
  "workspaceMount": "source=myproject-volume,target=/workspace,type=volume",
  "workspaceFolder": "/workspace",
  "postCreateCommand": "git submodule update --init --recursive"
}
```
This approach maintains performance while providing reproducible, isolated environments.

### 5.3 Clean-Up Command
Add a helper script to remove orphaned volumes:
```bash
docker volume prune --filter label=devcontainer
```

---

## 6. Common Pitfalls
- **Forgetting to push:** Work stored in a named volume may be lost if the volume is deleted.
- **Multiple clones:** You might inadvertently edit the host clone and container clone independently.
- **Submodules missing:** Remember to initialize them manually.
- **Stale data:** Reused volumes might contain outdated branches.
- **Credential errors:** SSH agent or token forwarding misconfiguration can block pushes.

---

## 7. Best Practices Summary
| Goal | Recommended Approach |
|------|-----------------------|
| Max performance | Clone repository into a named volume |
| Keep host and container in sync | Push/pull via remote Git service |
| Reproducibility | Use `devcontainer.json` with pinned image and `postCreateCommand` |
| Avoid staleness | Delete and re‑clone volumes periodically |
| Security | Forward only required credentials/SSH sockets |

---

## 8. References
- [VS Code Docs → Improve disk performance](https://code.visualstudio.com/remote/advancedcontainers/improve-performance)
- [VS Code Docs → Sharing Git credentials](https://code.visualstudio.com/remote/advancedcontainers/sharing-git-credentials)
- [Docker Volumes Guide](https://docs.docker.com/storage/volumes/)
- [Colima documentation](https://github.com/abiosoft/colima)

---

### TL;DR
- **Bind mount:** Simple but slow on macOS; shares Git state with host.
- **Named volume:** Fast and isolated; separate Git clone requiring manual sync.
- Always push to remote to safeguard work.
- Prune old volumes to avoid stale code and wasted disk space.

