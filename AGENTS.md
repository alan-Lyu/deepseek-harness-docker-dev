# Repository Guidelines

## Purpose & Architecture

This rebuildable DSH environment supplies isolated C/C++, Python, Rust, CMake/Ninja,
cross-compilers, and QEMU tooling while limiting agent host impact.

DSH must listen on `127.0.0.1:3080`, never `0.0.0.0`. `socat` bridges it to container `3081`;
Compose only publishes host `127.0.0.1:3080` and SSH port `2222`.

## Layout & Development Commands

- `docker-compose.yml` is the portable base (Linux, Windows, macOS); `docker-compose.linux.yml`
  adds Linux-only hardening (`apparmor=deepseek-harness`, `userns_mode: host`). The base keeps
  `seccomp=unconfined` for bubblewrap on every platform.
- `build/Dockerfile` installs toolchains and builds DSH.
- `build/docker-entrypoint.sh` starts SSH, port bridging, and DSH as `developer`.
- `workspace/` is the only host bind mount for development code; `/data/dsh` is the
  named `dsh-data` volume.

Linux users run `docker compose -f docker-compose.yml -f docker-compose.linux.yml config`,
`docker compose -f docker-compose.yml -f docker-compose.linux.yml build`, `docker compose -f
docker-compose.yml -f docker-compose.linux.yml up -d`, and `docker compose logs -f
deepseek-harness` from the root; Windows/macOS (Docker Desktop >= 4.42) run plain
`docker compose ...`. Pin an upstream branch/tag with
`docker compose build --build-arg DSH_REF=<ref>`. Docker requires host authority: agents provide
commands and await results, never invoking Docker. Builds need network.

Install resolver plugins with `pnpm add <package>` in `workspace/`; `PNPM_HOME` in `dsh-data`
preserves global pnpm tools across container rebuilds.

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
keys. Image/container rebuilds are safe; reset DSH state separately by removing
`dsh-data`. Preserve `workspace/` unless its deletion is separately confirmed.

`apparmor=deepseek-harness` must be installed on Linux hosts. `userns_mode: host` and
`seccomp=unconfined` remain compatibility exceptions for DSH `workspace-write`/bubblewrap.
Windows/macOS Docker Desktop hosts run the base config without AppArmor/userns hardening.
Hardening proceeds by:

1. Recording required namespaces, syscalls, and capabilities.
2. Replacing broad exceptions with minimal user-namespace mappings, capability allowlists, and
   custom seccomp/AppArmor profiles.
3. Enforcing default-deny egress through an audited allowlist proxy for model APIs, package sources,
   and approved destinations.
4. Adding resource limits, read-only/minimal mounts, loopback checks, and host-escape tests before
   removing the temporary exceptions.
