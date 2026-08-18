# Docker: DeepSeek Harness 开发环境

![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)　　➜　　![C](https://img.shields.io/badge/C-00599C?logo=c&logoColor=white)![C++](https://img.shields.io/badge/C++-%2300599C.svg?logo=c%2B%2B&logoColor=white)![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)![Rust](https://img.shields.io/badge/Rust-000000?logo=rust&logoColor=white)![QEMU](https://img.shields.io/badge/QEMU-FF6600?logo=qemu&logoColor=white)

---

这是一个基于 DeepSeek Harness（DSH）的协作开发 Docker 环境，集成 C/C++、Python、Rust、CMake/Ninja、交叉编译器，以及 ARM 和 RISC-V 的 QEMU 模拟环境。镜像和容器可以重建，DSH 状态与开发工作区可以分别管理和重置。

安全边界经过明确限制：DSH 在容器内固定监听回环地址 `127.0.0.1:3080`，由 `socat` 转发到容器端口 `3081`，宿主机只绑定 `127.0.0.1:3080`。SSH 仅允许公钥登录，关闭 root 登录和转发，不挂载 Docker socket。`workspace/` 是常规开发挂载区，不要挂载宿主敏感目录或私密凭据。Linux 宿主机启用 AppArmor 配置（`userns_mode: host` 和 `seccomp=unconfined` 是为兼容 DSH `workspace-write`/bubblewrap 保留的临时例外）；Windows/macOS Docker Desktop 宿主机不启用 AppArmor/userns 加固。本项目是受控开发环境，不是对抗恶意代码的完整沙箱。为方便开发，保留了 developer 用户的无密码 `sudo`。

## 使用方法

### 准备工作

支持的宿主机：

| 平台 | 要求 |
| --- | --- |
| Linux | Docker Engine 与 Compose v2、AppArmor、SSH 密钥对 |
| Windows | Docker Desktop ≥ 4.42（WSL2 后端）、SSH 密钥对 |
| macOS（Intel / Apple Silicon） | Docker Desktop ≥ 4.42、SSH 密钥对 |

私钥始终保留在宿主机上；运行时公钥注入方法见[首次运行指南](docs/README_FIRST_RUN.md)。要求 Docker Desktop ≥ 4.42 是因为该版本起默认应用 seccomp 配置；基础 compose 配置通过 `seccomp=unconfined` 为 DSH `workspace-write`/bubblewrap 关闭默认 seccomp。

启动服务前，在宿主机安装 AppArmor 配置（**仅限 Linux** —— Windows/macOS 跳过此步骤）：

```sh
sudo install -m 0644 build/deepseek-harness /etc/apparmor.d/deepseek-harness
sudo apparmor_parser -r /etc/apparmor.d/deepseek-harness
sudo aa-status | grep deepseek-harness
```

构建并启动环境。在 Linux 上，将加固覆盖文件与基础配置合并使用：

```sh
docker compose -f docker-compose.yml -f docker-compose.linux.yml config
docker compose -f docker-compose.yml -f docker-compose.linux.yml build --build-arg DSH_REF=master
SSH_PUB_KEY="$(cat ~/.ssh/id_ed25519.pub)" docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d
```

在 Windows（PowerShell）和 macOS 上，直接使用基础配置：

```sh
docker compose config
docker compose build --build-arg DSH_REF=master
docker compose up -d
```

PowerShell 首次运行（通过环境变量传入公钥）：

```powershell
$env:SSH_PUB_KEY = (Get-Content -Raw "$HOME\.ssh\id_ed25519.pub")
docker compose up -d
```

`DSH_REF` 可以指定 DSH 的分支或标签；也可以通过构建参数将容器内 developer 的 UID/GID 与宿主机工作区所有者对齐。公钥验证后保存在 `dsh-data` 中，后续启动无需再次提供 `SSH_PUB_KEY`。

浏览器访问 `http://127.0.0.1:3080`，或通过 SSH 连接：

```sh
ssh -i ~/.ssh/id_ed25519 -p 2222 developer@127.0.0.1
```

宿主机的 `workspace/` 映射到容器内的 `/home/developer/workspace`。DSH 会话、设置、token 和全局 pnpm 数据保存在名为 `dsh-data` 的卷中。在容器内可检查环境：

```sh
printenv DSH_HOME       # /data/dsh
dsh --help
cd /home/developer/workspace
```

全局 `dsh` 包装命令会在环境变量未继承时默认使用 `/data/dsh`。

---

### 内置工具链

镜像内置以下语言工具链和开发工具：

- C/C++：GNU GCC/G++、binutils、Clang、LLD、`build-essential`、CMake、Ninja、Make、`pkg-config`、Autoconf、Automake、Libtool 和 ccache。
- Python：Ubuntu 24.04 默认支持的 Python 3 稳定版本，并包含 pip、venv、开发头文件、OpenSSL 和 libffi 支持。
- Rust：公共的 rustup/Cargo 安装位于 `/usr/local/rustup` 和 `/usr/local/cargo`，默认选择 stable 工具链。初始安装会保留在带版本号的目录中，并通过 stable 符号链接提供；rustup 可以并行保留多个工具链。例如使用 `sudo rustup toolchain install 1.XX.0` 安装特定版本，用 `rustup toolchain list` 查看版本，用 `rustup override set 1.XX.0` 为项目指定版本；`sudo rustup update` 会更新公共安装。
- 交叉编译与模拟：AArch64 和 RISC-V 64 位 GCC/G++ 交叉编译器及 binutils，以及 ARM 和其他目标的 QEMU system 模拟器。
- 配套工具：Node.js 22.x、pnpm、Git、OpenSSH，以及常用调试和文档工具。

Dockerfile 是工具链版本和安装方式的唯一依据。如果项目需要特定版本的编译器、解释器、SDK 或工具链，可修改 Dockerfile 的软件包列表或安装步骤，然后重新构建镜像。

---

### 升级、日志与重置

使用新的分支或标签重新构建并重建服务即可升级 DSH：

```sh
docker compose build --build-arg DSH_REF=<branch-or-tag>
docker compose up -d --force-recreate
```

使用 `docker compose logs -f deepseek-harness` 查看日志，使用 `docker compose down` 停止服务。若要显式重置 DSH 状态，执行 `docker compose down -v`；该命令会删除 `dsh-data`（包括会话、设置、token 和全局 pnpm 工具），但会保留 `workspace/`。在 Linux 宿主机上，这些命令需加上 `-f docker-compose.yml -f docker-compose.linux.yml`。

## License

MIT © Alan Lyu – see [LICENSE](LICENSE) file for details.
