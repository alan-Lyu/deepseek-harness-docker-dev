# Use Ubuntu 24.04 LTS.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ========== 1. Install base tools, build dependencies, and isolation runtime ==========
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates curl wget vim tmux htop sudo tini socat util-linux \
    build-essential cmake ninja-build pkg-config \
    autoconf automake libtool \
    clang lld \
    zip unzip \
    git \
    openssh-server \
    python3 python3-pip python3-venv python3-dev \
    libssl-dev libffi-dev \
    ccache doxygen graphviz \
    locales \
    bubblewrap \
    qemu-system-arm qemu-system-misc \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    gcc-riscv64-linux-gnu g++-riscv64-linux-gnu binutils-riscv64-linux-gnu \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# ========== 2. Pin tar to version 1.34 ==========
# Ubuntu 24.04 includes tar 1.34, but it may need to be downgraded if the base image changes.
# Build and install version 1.34 from source to ensure the required version.
RUN curl -fsSL https://ftp.gnu.org/gnu/tar/tar-1.34.tar.gz -o /tmp/tar-1.34.tar.gz \
    && cd /tmp \
    && tar -xzf tar-1.34.tar.gz \
    && cd tar-1.34 \
    && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install \
    && cd / && rm -rf /tmp/tar-1.34*

# ========== 3. Install Rust ==========
# Set the rustup and Cargo installation directories.
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
# 1. Resolve and install the latest stable Rust version.
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

# ========== 4. Install Node.js 22.x and pnpm ==========
RUN set -eux; \
    curl -fsSL https://deb.nodesource.com/setup_22.x \
      -o /tmp/nodesource_setup.sh; \
    bash /tmp/nodesource_setup.sh; \
    apt-get install -y nodejs; \
    node -e 'if (Number(process.versions.node.split(".")[0]) !== 22) process.exit(1)'; \
    npm --version; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ========== 5. Clone and build DeepSeek Harness ==========
ARG DSH_REF=master
WORKDIR /app
RUN git clone --depth 1 --branch "${DSH_REF}" https://github.com/deepseek-ai/deepseek-harness.git . \
    && PNPM_VERSION="$(node -p "JSON.parse(require('fs').readFileSync('package.json')).packageManager.split('@').pop()")" \
    && npm install -g "pnpm@${PNPM_VERSION}" \
    && pnpm install --frozen-lockfile \
    && pnpm run build \
    && chmod 0755 /app/apps/cli/lib/bin.js \
    && printf '%s\n' \
       '#!/bin/sh' \
       'export DSH_HOME="${DSH_HOME:-/data/dsh}"' \
       'exec /app/apps/cli/lib/bin.js "$@"' \
       > /usr/local/bin/dsh \
    && chmod 0755 /usr/local/bin/dsh

# ========== 6. Create the developer user ==========
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
    printf '%s\n' \
       'developer ALL=(ALL) NOPASSWD:ALL' \
       'Defaults:developer secure_path="/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' \
       'Defaults:developer env_keep += "RUSTUP_HOME DSH_HOME PNPM_HOME"' \
       > /etc/sudoers.d/developer; \
    chmod 0440 /etc/sudoers.d/developer; \
    mkdir -p /home/developer/.ssh /home/developer/.cargo /home/developer/workspace; \
    chmod 700 /home/developer/.ssh; \
    install -o developer -g developer -m 0600 /dev/null /home/developer/.ssh/authorized_keys; \
    chown -R developer:developer /home/developer

# Provide an independent launcher manifest while keeping DSH's working directory in the mounted workspace.
COPY --chown=developer:developer dsh-launcher-package.json \
    /home/developer/.dsh-launcher/package.json

RUN chown -R developer:developer /home/developer/.dsh-launcher \
    && install -d -m 0755 /run/sshd /etc/ssh/sshd_config.d \
    && printf '%s\n' \
       'Port 2222' \
       'PermitRootLogin no' \
       'PasswordAuthentication no' \
       'KbdInteractiveAuthentication no' \
       'PubkeyAuthentication yes' \
       'AuthenticationMethods publickey' \
       'AllowUsers developer' \
       'AllowAgentForwarding no' \
       'AllowTcpForwarding no' \
       'PermitTunnel no' \
       'PermitUserEnvironment no' \
       'X11Forwarding no' \
       'SetEnv CARGO_HOME=/home/developer/.cargo RUSTUP_HOME=/usr/local/rustup PNPM_HOME=/data/dsh/pnpm DSH_HOME=/data/dsh' \
       > /etc/ssh/sshd_config.d/99-dsh.conf \
    && printf '%s\n' \
       'export CARGO_HOME=/home/developer/.cargo' \
       'export RUSTUP_HOME=/usr/local/rustup' \
       'export PNPM_HOME=/data/dsh/pnpm' \
       'export DSH_HOME=/data/dsh' \
       'export PATH=/home/developer/.cargo/bin:/usr/local/cargo/bin:$PATH:$PNPM_HOME' \
       >> /home/developer/.profile \
    && chown developer:developer /home/developer/.profile \
    && /usr/sbin/sshd -t

# Configure developer environment variables.
ENV DEV_USER=developer
ENV DEVELOPER_HOME=/home/developer
ENV DSH_HOME=/data/dsh
ENV PNPM_HOME=/data/dsh/pnpm
ENV PATH="${PATH}:${PNPM_HOME}"

RUN mkdir -p /data/dsh "${PNPM_HOME}" \
    && chown developer:developer /data/dsh "${PNPM_HOME}" \
    && chmod 0700 /data/dsh "${PNPM_HOME}"

VOLUME /data/dsh

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

# ========== 7. Start the service ==========
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["pnpm", "dsh", "web"]

EXPOSE 3081 2222
