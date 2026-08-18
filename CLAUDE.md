# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose & Architecture

This repo builds a Docker environment around DeepSeek Harness (DSH): the image contains C/C++,
Python, Rust, CMake/Ninja, AArch64/RISC-V cross-compilers, QEMU, and Node 22 + pnpm; the Compose
service runs DSH plus an SSH daemon while limiting host impact. Deploy targets: Linux hosts
(Docker Engine + AppArmor) and Windows/macOS via Docker Desktop ≥ 4.42 (WSL2 backend on Windows).
This is not a DSH fork — DSH itself is cloned from
`deepseek-ai/deepseek-harness` at image build time (`build/Dockerfile` is the source of truth for
toolchains; adjust its package list when a project needs a specific toolchain version, then rebuild).

### Runtime topology (spans Dockerfile, entrypoint, compose)

- Compose is split into a portable base (`docker-compose.yml`, every platform) and a Linux
  hardening overlay (`docker-compose.linux.yml`: `userns_mode: host` +
  `apparmor=deepseek-harness`). `security_opt` lists append across `-f` files, so the base's
  `seccomp=unconfined` (required for bubblewrap wherever the default seccomp profile applies)
  is always present and AppArmor applies only on Linux.
- DSH must listen on container loopback `127.0.0.1:3080`, never `0.0.0.0`. `socat` bridges it to
  container port `3081`; Compose publishes host `127.0.0.1:3080 -> 3081`. SSH maps host
  `127.0.0.1:2222 -> 2222` (public-key only, root login and forwarding disabled).
- Entrypoint (`build/docker-entrypoint.sh`, root under tini): initializes SSH state, starts sshd
  and socat, then `exec runuser -u developer` for the CMD.
- CMD is `pnpm dsh web`, executed from `/home/developer/.dsh-launcher` — a minimal manifest
  (`build/dsh-launcher-package.json`) whose `dsh` script does `cd /home/developer/workspace &&
  exec /usr/local/bin/dsh`. DSH's working directory is therefore the workspace bind mount, which
  matters for `workspace-write`. `/usr/local/bin/dsh` is a wrapper around the built CLI
  (`/app/apps/cli/lib/bin.js`) that exports `DSH_HOME`.

### SSH: initialized at runtime, not build time

On first start (or after `dsh-data` is deleted) `SSH_PUB_KEY` must be provided; the entrypoint
validates it with `ssh-keygen -l` and persists it to `dsh-data/ssh/authorized_keys`. Subsequent
starts need no key; rotate by passing a new key with `--force-recreate`. See
`docs/README_FIRST_RUN.md` (bilingual) for full first-run and published-image `docker run` usage.

### Persistence split

- `workspace/` (bind mount -> `/home/developer/workspace`): the only host-shared dev code path;
  survives image rebuilds and `down -v`.
- `dsh-data` (named volume -> `/data/dsh`): `DSH_HOME` (sessions/settings/tokens),
  `PNPM_HOME` (`/data/dsh/pnpm`, preserves global pnpm tools across rebuilds — install resolver
  plugins there with `pnpm add <package>` in `workspace/`), and SSH state. Reset DSH state by
  removing this volume only.

### Environment plumbing that must agree

`DSH_HOME=/data/dsh` and the Rust/pnpm paths are set in five places: Dockerfile `ENV`, compose
`environment`, sudoers `env_keep`/`secure_path`, sshd `SetEnv` (`/etc/ssh/sshd_config.d/99-dsh.conf`),
and `/home/developer/.profile`. Change one and check all. `DSH_PORT` (default 3080) feeds both the
socat target and the DSH process.

### Rust toolchain layout

Shared rustup/Cargo under `/usr/local/rustup` + `/usr/local/cargo`, with versioned directories
(`rustup-<ver>`, `cargo-<ver>`) exposed through stable symlinks so multiple toolchains coexist.
Manage inside the container with `sudo rustup toolchain install X.Y.Z` /
`rustup override set X.Y.Z` / `sudo rustup update`.

### CI

`.github/workflows/docker-publish.yml` builds and pushes `linux/amd64` + `linux/arm64` images to
GHCR on push to `main` and `v*.*.*` tags (PRs build without pushing), then cosign-signs the digest.

## Commands

All from the repo root. Linux (merge the hardening overlay with the portable base):

```sh
# One-time host setup (Linux only — skip on Windows/macOS): install the AppArmor profile
sudo install -m 0644 build/deepseek-harness /etc/apparmor.d/deepseek-harness
sudo apparmor_parser -r /etc/apparmor.d/deepseek-harness
sudo aa-status | grep deepseek-harness

docker compose -f docker-compose.yml -f docker-compose.linux.yml config
docker compose -f docker-compose.yml -f docker-compose.linux.yml build --build-arg DSH_REF=<branch-or-tag>   # needs network
SSH_PUB_KEY="$(cat ~/.ssh/id_ed25519.pub)" docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d   # key required on first run only
```

Windows (PowerShell) / macOS — base configuration only, Docker Desktop ≥ 4.42:

```powershell
docker compose build --build-arg DSH_REF=<branch-or-tag>
$env:SSH_PUB_KEY = (Get-Content -Raw "$HOME\.ssh\id_ed25519.pub")
docker compose up -d
```

Common (add the `-f` file pair on Linux):

```sh
docker compose logs -f deepseek-harness
docker compose down              # stop
docker compose down -v           # reset DSH state (removes dsh-data; workspace/ preserved)
docker compose up -d --force-recreate   # apply a rebuild or key rotation
```

In-container smoke checks:

```sh
ssh -i ~/.ssh/id_ed25519 -p 2222 developer@127.0.0.1
printenv DSH_HOME && dsh --help && cd /home/developer/workspace
```

No formatter or test framework is configured; validation is manual.

## Conventions

- Docker authority stays with the user: agents provide commands and await results, never invoke
  Docker themselves.
- 2-space YAML nesting; 4-space shell continuations; quote shell variables; `set -eu` in entrypoint
  scripts. Kebab-case service/file names; uppercase env var names (`DSH_HOME`).
- Commits: concise imperative with a component prefix, e.g. `[Docker] DeepSeek Harness Docker based
  on Ubuntu 24.04`. PRs must describe runtime/security impact, validation results, and any changed
  ports/volumes/permissions.

## Security Baseline & Roadmap

Never mount the Docker socket, host-sensitive paths, or secrets; never commit tokens or private
keys. On Linux hosts, `apparmor=deepseek-harness` must be installed before the service starts;
`userns_mode: host` and `seccomp=unconfined` are deliberate temporary exceptions for DSH
`workspace-write`/bubblewrap. Windows/macOS Docker Desktop hosts run the base config without
AppArmor/userns hardening. Image/container rebuilds are safe; resetting DSH state means removing
`dsh-data`; preserve `workspace/` unless its deletion is separately confirmed.

Hardening proceeds by:

1. Recording required namespaces, syscalls, and capabilities.
2. Replacing broad exceptions with minimal user-namespace mappings, capability allowlists, and
   custom seccomp/AppArmor profiles.
3. Enforcing default-deny egress through an audited allowlist proxy for model APIs, package sources,
   and approved destinations.
4. Adding resource limits, read-only/minimal mounts, loopback checks, and host-escape tests before
   removing the temporary exceptions.
