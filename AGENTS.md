# Repository Guidelines

## Purpose & Architecture

This rebuildable DeepSeek Harness (DSH) environment supports C/C++, Python, and Rust with
CMake/Ninja, cross-compilers, and QEMU. It isolates toolchains, limits an AI agent's host impact,
and supports disposable development.

DSH must listen only on container loopback at `127.0.0.1:3080`; do not change it to bind
`0.0.0.0`. `build/docker-entrypoint.sh` uses `socat` to bridge that service to container port
`3081`, and Compose publishes it only as host `127.0.0.1:3080`. SSH is likewise bound to host
loopback on port `2222`.

## Layout & Development Commands

- `docker-compose.yml` defines runtime isolation, ports, volumes, and health checks.
- `build/Dockerfile` installs the toolchains and builds upstream DSH.
- `build/docker-entrypoint.sh` starts SSH, the port bridge, and DSH as `developer`.
- `workspace/` is the only routine host bind mount for development code; `/data/dsh` is the
  persistent named `dsh-data` volume.

From the repository root, users can run `docker compose config`, `docker compose build`,
`docker compose up -d`, and `docker compose logs -f deepseek-harness`. Docker commands require
host/root authority: agents must provide the exact command and wait for the user’s result rather
than invoking Docker tools. Builds download external dependencies and require a working network.

## Conventions, Tests & Reviews

Use 2-space YAML nesting, 4-space shell continuations, quoted shell variables, and `set -eu` in
entrypoint scripts. Use lowercase kebab-case service/file names and uppercase environment-variable
names such as `DSH_HOME`. No formatter or test framework is configured. Before review, have the
user validate Compose and smoke-test DSH `workspace-write`, C/C++/Python/Rust/QEMU tooling, the
loopback web and SSH endpoints, and persistence across a container restart.

Use concise imperative commits with component prefixes, for example `[Docker] DeepSeek Harness
Docker based on Ubuntu 24.04`. Pull requests must describe runtime/security impact, validation
results, and changed ports, volumes, or permissions.

## Security Baseline & Roadmap

Never mount the Docker socket, host-sensitive paths, or secrets; do not commit tokens or private
keys. Image/container rebuilds are safe; reset DSH state separately by explicitly removing
`dsh-data`. Preserve `workspace/` unless its deletion is separately confirmed.

`userns_mode: host`, `apparmor=unconfined`, and `seccomp=unconfined` are temporary compatibility
exceptions for DSH `workspace-write`/bubblewrap, not the target posture. Hardening proceeds by:

1. Recording required namespaces, syscalls, and capabilities.
2. Replacing broad exceptions with minimal user-namespace mappings, capability allowlists, and
   custom seccomp/AppArmor profiles.
3. Enforcing default-deny egress through an audited allowlist proxy for model APIs, package sources,
   and approved destinations.
4. Adding resource limits, read-only/minimal mounts, loopback checks, and host-escape tests before
   removing the temporary exceptions.
