# Docker: DeepSeek Harness Development Environment

![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)　　➜　　![C](https://img.shields.io/badge/C-00599C?logo=c&logoColor=white)![C++](https://img.shields.io/badge/C++-%2300599C.svg?logo=c%2B%2B&logoColor=white)![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)![Rust](https://img.shields.io/badge/Rust-000000?logo=rust&logoColor=white)![QEMU](https://img.shields.io/badge/QEMU-FF6600?logo=qemu&logoColor=white)

---

This repository provides a collaborative Docker environment built around DeepSeek Harness (DSH). It combines C/C++, Python, Rust, CMake/Ninja, cross-compilers, and QEMU for ARM and RISC-V targets. The image and container are rebuildable, while DSH state and the workspace can be reset independently.

DSH listens on container loopback `127.0.0.1:3080`; `socat` bridges it to container port `3081`, and the host publishes only `127.0.0.1:3080`. SSH is public-key-only on host port `2222`, root login and forwarding are disabled, and no Docker socket is mounted. Use only `workspace/` for normal host sharing; keep sensitive paths and credentials out. On Linux hosts an AppArmor profile is applied (`userns_mode: host` and `seccomp=unconfined` are temporary DSH bubblewrap exceptions); Windows/macOS Docker Desktop hosts run without the AppArmor/userns hardening. This is a controlled development environment, not a hostile-code sandbox. Passwordless developer `sudo` is retained for convenience.

## Usage

### Prerequisites

Supported hosts:

| Platform | Requirements |
| --- | --- |
| Linux | Docker Engine with Compose v2, AppArmor, an SSH key pair |
| Windows | Docker Desktop ≥ 4.42 with the WSL2 backend, an SSH key pair |
| macOS (Intel / Apple Silicon) | Docker Desktop ≥ 4.42, an SSH key pair |

Keep the private key on the host. See [First Run](docs/README_FIRST_RUN.md) for runtime public-key injection. Docker Desktop ≥ 4.42 is required because it applies the default seccomp profile; the base configuration disables it (`seccomp=unconfined`) for DSH `workspace-write`/bubblewrap.

Install the host AppArmor profile before starting the service (**Linux only** — Windows/macOS hosts skip this step):

```sh
sudo install -m 0644 build/deepseek-harness /etc/apparmor.d/deepseek-harness
sudo apparmor_parser -r /etc/apparmor.d/deepseek-harness
sudo aa-status | grep deepseek-harness
```

Build and start the environment. On Linux, merge the hardening overlay with the portable base:

```sh
docker compose -f docker-compose.yml -f docker-compose.linux.yml config
docker compose -f docker-compose.yml -f docker-compose.linux.yml build --build-arg DSH_REF=master
SSH_PUB_KEY="$(cat ~/.ssh/id_ed25519.pub)" docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d
```

On Windows (PowerShell) and macOS, use the base configuration directly:

```sh
docker compose config
docker compose build --build-arg DSH_REF=master
docker compose up -d
```

PowerShell first run (pass the key through an environment variable):

```powershell
$env:SSH_PUB_KEY = (Get-Content -Raw "$HOME\.ssh\id_ed25519.pub")
docker compose up -d
```

`DSH_REF` may be a DSH branch or tag. The validated key is persisted in `dsh-data`; subsequent starts do not require `SSH_PUB_KEY`.

Open DSH at `http://127.0.0.1:3080`, or connect over SSH:

```sh
ssh -i ~/.ssh/id_ed25519 -p 2222 developer@127.0.0.1
```

The host `workspace/` directory maps to `/home/developer/workspace`. Persistent DSH sessions, settings, tokens, and global pnpm data reside in the named `dsh-data` volume. Inside the container, verify the routing with:

```sh
printenv DSH_HOME       # /data/dsh
dsh --help
cd /home/developer/workspace
```

---

### Built-in Toolchains

The image includes the following toolchains and development utilities:

- C/C++: GNU GCC/G++, binutils, Clang, LLD, `build-essential`, CMake, Ninja, Make, `pkg-config`, Autoconf, Automake, Libtool, and ccache.
- Python: Ubuntu 24.04's supported Python 3 release, plus pip, venv, development headers, OpenSSL, and libffi support.
- Rust: a shared system rustup/Cargo installation under `/usr/local/rustup` and `/usr/local/cargo`, with the stable toolchain selected by default. The initial installation is kept in versioned directories and exposed through stable symlinks; rustup can retain multiple toolchains side by side. For example, use `sudo rustup toolchain install 1.XX.0`, `rustup toolchain list`, and `rustup override set 1.XX.0`. `sudo rustup update` updates the shared installation.
- Cross-compilation and emulation: AArch64 and RISC-V 64-bit GCC/G++ cross-compilers and binutils, plus QEMU system emulators for ARM and miscellaneous targets.
- Supporting tools: Node.js 22.x, pnpm, Git, OpenSSH, and common debugging and documentation tools.

The Dockerfile is the source of truth. Modify its package list or installation steps when a project requires a specific compiler, interpreter, SDK, or toolchain version, then rebuild the image.

---

### Upgrade, Logs, and Reset

Upgrade DSH by rebuilding with a new branch or tag, then recreate the service:

```sh
docker compose build --build-arg DSH_REF=<branch-or-tag>
docker compose up -d --force-recreate
```

Use `docker compose logs -f deepseek-harness` for logs and `docker compose down` to stop. `docker compose down -v` resets DSH by removing `dsh-data` while preserving `workspace/`. On Linux hosts, add `-f docker-compose.yml -f docker-compose.linux.yml` to these commands.

## License

MIT © Alan Lyu – see [LICENSE](LICENSE) file for details.
