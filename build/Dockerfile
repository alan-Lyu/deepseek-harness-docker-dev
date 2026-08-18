# 使用 Ubuntu 24.04 LTS
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ========== 1. 安装基础工具和编译依赖 ==========
RUN apt-get update
RUN apt-get install -y \
    curl wget vim tmux htop sudo \
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

# ========== 2. 固定 tar 版本为 1.34 ==========
# Ubuntu 24.04 自带 tar 1.34，但如果升级过则需手动降级。这里直接从源码编译安装 1.34 并覆盖系统 tar。
RUN curl -fsSL https://ftp.gnu.org/gnu/tar/tar-1.34.tar.gz -o /tmp/tar-1.34.tar.gz \
    && cd /tmp \
    && tar -xzf tar-1.34.tar.gz \
    && cd tar-1.34 \
    && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install \
    && cd / && rm -rf /tmp/tar-1.34*

# ========== 3. 安装 QEMU 和交叉编译工具链 ==========
RUN apt-get install -y \
    qemu-system-arm qemu-system-misc \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    gcc-riscv64-linux-gnu g++-riscv64-linux-gnu binutils-riscv64-linux-gnu

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
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm

# ========== 6. 配置 SSH 服务 ==========
RUN mkdir /var/run/sshd \
    && echo 'root:root' | chpasswd \
    && sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ========== 7. 克隆/构建 DeepSeek Harness ==========
WORKDIR /app
RUN git clone --depth 1 https://github.com/deepseek-ai/deepseek-harness.git . \
    && pnpm install --frozen-lockfile \
    && pnpm run build

ENV DSH_HOME=/data/dsh
VOLUME /data/dsh

RUN sed -ri 's/^%sudo\s+ALL=\(ALL:ALL\)\s+ALL/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/' /etc/sudoers

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ========== 8. 创建开发者用户 ==========
RUN useradd -m -s /bin/bash developer \
    && usermod -aG sudo developer \
    && passwd -l developer \
    && echo 'developer ALL=(ALL) NOPASSWD:ALL' \
       > /etc/sudoers.d/developer \
    && chmod 0440 /etc/sudoers.d/developer \
    && mkdir -p /home/developer/.ssh \
    && chmod 700 /home/developer/.ssh

# 配置 SSH 公钥认证
COPY --chown=developer:developer authorized_keys \
    /home/developer/.ssh/authorized_keys

RUN chmod 600 /home/developer/.ssh/authorized_keys \
    && printf '\nMatch User developer\n\
    PasswordAuthentication no\n\
    PubkeyAuthentication yes\n' \
    >> /etc/ssh/sshd_config

# 配置开发者环境变量
ENV DEV_USER=developer
ENV DEVELOPER_HOME=/home/developer

# ========== 9. 启动服务 ==========
CMD ["sh", "-c", "/usr/sbin/sshd -D & exec pnpm dsh web"]

EXPOSE 3080 2222