# First Run / 首次运行

SSH access is initialized at runtime. Provide an OpenSSH public key through `SSH_PUB_KEY` on the first start; the entrypoint validates it and stores it in the persistent `dsh-data` volume. Never pass a private key, token, or other secret through this variable.

SSH 访问在运行时初始化。首次启动时通过 `SSH_PUB_KEY` 提供 OpenSSH 公钥；入口脚本验证后将其保存在持久化的 `dsh-data` 卷中。不要通过该变量传入私钥、token 或其他秘密。

## Start with Compose / 使用 Compose 启动

Install the AppArmor profile (Linux only — skip on Windows/macOS), create the workspace, then build and start. On Linux, merge the hardening overlay with the portable base:

安装 AppArmor 配置（仅限 Linux —— Windows/macOS 跳过）、创建工作区，然后构建并启动。在 Linux 上，将加固覆盖文件与基础配置合并使用：

```sh
sudo install -m 0644 build/deepseek-harness /etc/apparmor.d/deepseek-harness
sudo apparmor_parser -r /etc/apparmor.d/deepseek-harness
mkdir -p workspace
SSH_PUB_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d --build
```

On Windows (PowerShell) and macOS, use the base configuration directly:

在 Windows（PowerShell）和 macOS 上，直接使用基础配置：

```powershell
New-Item -ItemType Directory -Force workspace
$env:SSH_PUB_KEY = (Get-Content -Raw "$HOME\.ssh\id_ed25519.pub")
docker compose up -d --build
```

After initialization, ordinary starts need no key variable (on Linux, add `-f docker-compose.yml -f docker-compose.linux.yml`):

初始化完成后，普通启动无需再次提供公钥变量（Linux 需加上 `-f docker-compose.yml -f docker-compose.linux.yml`）：

```sh
docker compose up -d
```

## Start a Published Image / 启动已发布镜像

Replace the example `DSH_IMAGE` value with the registry image name. The AppArmor profile must already be installed from this repository (Linux only).

将示例中的 `DSH_IMAGE` 值替换为镜像仓库中的实际名称；宿主机必须已经从本仓库安装 AppArmor 配置（仅限 Linux）。

```sh
export DSH_IMAGE=ghcr.io/owner/image:tag
docker pull "${DSH_IMAGE}"
mkdir -p workspace
docker volume create dsh-data
docker run -d \
  --name deepseek-harness \
  --hostname dsh-dev \
  --restart unless-stopped \
  --pids-limit 1024 \
  --userns=host \
  --security-opt apparmor=deepseek-harness \
  --security-opt seccomp=unconfined \
  -p 127.0.0.1:3080:3081 \
  -p 127.0.0.1:2222:2222 \
  --mount source=dsh-data,target=/data/dsh \
  --mount type=bind,source="$(pwd)/workspace",target=/home/developer/workspace \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  "${DSH_IMAGE}"
```

On Windows/macOS Docker Desktop, omit `--userns=host` and `--security-opt apparmor=deepseek-harness` (Linux-only hardening); `--security-opt seccomp=unconfined` is still required:

在 Windows/macOS Docker Desktop 上，去掉 `--userns=host` 和 `--security-opt apparmor=deepseek-harness`（仅限 Linux 的加固项）；`--security-opt seccomp=unconfined` 仍然需要：

```sh
docker run -d \
  --name deepseek-harness \
  --hostname dsh-dev \
  --restart unless-stopped \
  --pids-limit 1024 \
  --security-opt seccomp=unconfined \
  -p 127.0.0.1:3080:3081 \
  -p 127.0.0.1:2222:2222 \
  --mount source=dsh-data,target=/data/dsh \
  --mount type=bind,source="$(pwd)/workspace",target=/home/developer/workspace \
  -e SSH_PUB_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  "${DSH_IMAGE}"
```

PowerShell key passing:

PowerShell 传入公钥：

```powershell
$env:SSH_PUB_KEY = (Get-Content -Raw "$HOME\.ssh\id_ed25519.pub")
```

Open `http://127.0.0.1:3080` or connect with:

访问 `http://127.0.0.1:3080`，或通过 SSH 连接：

```sh
ssh -i ~/.ssh/id_ed25519 -p 2222 developer@127.0.0.1
```

To rotate the key with Compose, provide a new value while recreating the container:

如需通过 Compose 轮换公钥，在重建容器时提供新值：

```sh
SSH_PUB_KEY="$(cat ~/.ssh/new_key.pub)" docker compose up -d --force-recreate
```

Deleting `dsh-data` also deletes the stored SSH key. The next start must provide `SSH_PUB_KEY` again. A missing or invalid first-run key causes the container to stop with an explanatory log message.

删除 `dsh-data` 也会删除已保存的 SSH 公钥。下次启动必须重新提供 `SSH_PUB_KEY`；首次运行时缺少公钥或格式无效会使容器停止，并在日志中给出原因。
