#!/bin/sh
set -eu

DSH_DATA_DIR=/data/dsh
PNPM_HOME="${DSH_DATA_DIR}/pnpm"

umask 077

install -d -m 0755 /run/sshd
install -d -o developer -g developer -m 0700 "${DSH_DATA_DIR}"
chown -R developer:developer "${DSH_DATA_DIR}"
chmod 0700 "${DSH_DATA_DIR}"
install -d -o developer -g developer -m 0700 "${PNPM_HOME}"
install -d -o developer -g developer -m 0755 /home/developer/workspace

/usr/sbin/sshd -e

# DSH listens on the container loopback address; socat exposes a bridge port for Docker mapping.
socat \
    TCP-LISTEN:3081,bind=0.0.0.0,reuseaddr,fork \
    "TCP:127.0.0.1:${DSH_PORT:-3080}" &

cd /home/developer/.dsh-launcher

exec /usr/sbin/runuser -u developer -- env \
    HOME=/home/developer \
    CARGO_HOME=/home/developer/.cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PNPM_HOME="${PNPM_HOME}" \
    PATH="/home/developer/.cargo/bin:/usr/local/cargo/bin:${PATH}:${PNPM_HOME}" \
    DSH_HOME="${DSH_DATA_DIR}" \
    DSH_PORT="${DSH_PORT:-3080}" \
    "$@"
