# 使用 Ubuntu 24.04 LTS
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ========== 1. 安装基础工具和编译依赖 ==========
RUN apt-get update
RUN apt-get install -y \
    curl wget vim tmux htop sudo tini socat \
    build-essential cmake ninja-build pkg-config \
    autoconf automake libtool \
    clang lld \
    zip unzip \
    openssh-server \
    python3 python3-pip python3-venv python3-dev \
    libssl-dev libffi-dev \
    ccache doxygen graphviz \
    locales \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

RUN apt-get install -y software-properties-common

RUN add-apt-repository ppa:git-core/ppa && apt-get update && apt-get install -y git

# ========== 2. 安装 QEMU 和交叉编译工具链 ==========
RUN apt-get install -y \
    qemu-system-arm qemu-system-misc \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    gcc-riscv64-linux-gnu g++-riscv64-linux-gnu binutils-riscv64-linux-gnu

# ========== 3. 固定 tar 版本为 1.34 ==========
# Ubuntu 24.04 自带 tar 1.34，但如果升级过则需手动降级。这里直接从源码编译安装 1.34 并覆盖系统 tar。
RUN curl -fsSL https://ftp.gnu.org/gnu/tar/tar-1.34.tar.gz -o /tmp/tar-1.34.tar.gz \
    && cd /tmp \
    && tar -xzf tar-1.34.tar.gz \
    && cd tar-1.34 \
    && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install \
    && cd / && rm -rf /tmp/tar-1.34*

# dsh workspace-write 在 Linux 下优先使用 bubblewrap 作为沙箱后端。
RUN apt-get install -y bubblewrap

# ========== 4. 安装 Rust ==========
# 设置环境变量，指定 rustup 和 cargo 的安装目录
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
# 1. 获取最新稳定版本号并安装 Rust latest
RUN set -eux; \
    RUST_VERSION="$(curl -fsSL \
      https://static.rust-lang.org/dist/channel-rust-stable.toml | \
      sed -n '/^\[pkg\.rust\]$/,/^\[/ { \
        s/^version = "\([0-9][0-9.]*\).*/\1/p \
      }' | head -n 1)"; \
    test -n "${RUST_VERSION}"; \
    echo "Installing Rust ${RUST_VERSION}"; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
      sh -s -- -y \
      --default-toolchain "${RUST_VERSION}" \
      --profile minimal \
      --no-modify-path; \
    mv /usr/local/cargo "/usr/local/cargo-${RUST_VERSION}"; \
    mv /usr/local/rustup "/usr/local/rustup-${RUST_VERSION}"; \
    ln -s "/usr/local/cargo-${RUST_VERSION}" /usr/local/cargo; \
    ln -s "/usr/local/rustup-${RUST_VERSION}" /usr/local/rustup
ENV PATH="/usr/local/cargo/bin:${PATH}"

# ========== 5. 安装 Node.js 22.x 和 pnpm ==========
RUN set -eux; \
    curl -fsSL https://deb.nodesource.com/setup_22.x \
      -o /tmp/nodesource_setup.sh; \
    bash /tmp/nodesource_setup.sh; \
    apt-get install -y nodejs; \
    node -e 'if (Number(process.versions.node.split(".")[0]) !== 22) process.exit(1)'; \
    npm --version; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ========== 6. 配置 SSH 服务 ==========
RUN mkdir /var/run/sshd \
    && echo 'root:root' | chpasswd \
    && sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ========== 7. 克隆/构建 DeepSeek Harness ==========
WORKDIR /app
RUN git clone --depth 1 https://github.com/deepseek-ai/deepseek-harness.git . \
    && PNPM_VERSION="$(node -p "JSON.parse(require('fs').readFileSync('package.json')).packageManager.split('@').pop()")" \
    && npm install -g "pnpm@${PNPM_VERSION}" \
    && pnpm install --frozen-lockfile \
    && pnpm run build \
    && chmod 0755 /app/apps/cli/lib/bin.js \
    && ln -s /app/apps/cli/lib/bin.js /usr/local/bin/dsh

# ========== 8. 创建开发者用户 ==========
ARG DEV_UID=1000
ARG DEV_GID=1000
RUN set -eux; \
    EXISTING_GROUP="$(getent group "${DEV_GID}" | cut -d: -f1)"; \
    if [ -n "${EXISTING_GROUP}" ] && [ "${EXISTING_GROUP}" != developer ]; then \
      groupmod --new-name developer "${EXISTING_GROUP}"; \
    elif ! getent group developer >/dev/null; then \
      groupadd --gid "${DEV_GID}" developer; \
    fi; \
    EXISTING_USER="$(getent passwd "${DEV_UID}" | cut -d: -f1)"; \
    if [ -n "${EXISTING_USER}" ] && [ "${EXISTING_USER}" != developer ]; then \
      usermod --login developer --home /home/developer --move-home "${EXISTING_USER}"; \
    elif ! getent passwd developer >/dev/null; then \
      useradd --uid "${DEV_UID}" --gid developer -m -s /bin/bash developer; \
    fi; \
    usermod --gid developer --append --groups sudo developer; \
    usermod --password "$(openssl passwd -6 "$(openssl rand -hex 32)")" developer; \
    printf '%s\n' \
       'developer ALL=(ALL) NOPASSWD:ALL' \
       'Defaults:developer secure_path="/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' \
       'Defaults:developer env_keep += "RUSTUP_HOME"' \
       > /etc/sudoers.d/developer; \
    chmod 0440 /etc/sudoers.d/developer; \
    mkdir -p /home/developer/.ssh /home/developer/.cargo /home/developer/workspace; \
    chmod 700 /home/developer/.ssh; \
    chown -R developer:developer /home/developer

# 配置 SSH 公钥认证
COPY --chown=developer:developer authorized_keys \
    /home/developer/.ssh/authorized_keys

# 为官方启动命令提供独立清单，同时让 dsh 的实际工作目录保持为挂载的 workspace。
COPY --chown=developer:developer dsh-launcher-package.json \
    /home/developer/.dsh-launcher/package.json

RUN chmod 600 /home/developer/.ssh/authorized_keys \
    && chown -R developer:developer /home/developer/.dsh-launcher \
    && printf '\nMatch User developer\n\
    AuthenticationMethods publickey\n\
    PasswordAuthentication no\n\
    KbdInteractiveAuthentication no\n\
    PubkeyAuthentication yes\n\
    SetEnv CARGO_HOME=/home/developer/.cargo RUSTUP_HOME=/usr/local/rustup\n' \
    >> /etc/ssh/sshd_config \
    && printf '%s\n' \
       'export CARGO_HOME=/home/developer/.cargo' \
       'export RUSTUP_HOME=/usr/local/rustup' \
       'export PATH=/home/developer/.cargo/bin:/usr/local/cargo/bin:$PATH' \
       >> /home/developer/.profile \
    && chown developer:developer /home/developer/.profile \
    && /usr/sbin/sshd -t

# 配置开发者环境变量
ENV DEV_USER=developer
ENV DEVELOPER_HOME=/home/developer
ENV DSH_HOME=/data/dsh

RUN mkdir -p /data/dsh \
    && chown developer:developer /data/dsh

VOLUME /data/dsh

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

# ========== 9. 启动服务 ==========
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["pnpm", "dsh", "web"]

EXPOSE 3081 2222
