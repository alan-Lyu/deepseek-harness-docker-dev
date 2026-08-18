#!/bin/sh
set -eu

DSH_DATA_DIR=/data/dsh
PNPM_HOME="${DSH_DATA_DIR}/pnpm"
SSH_STATE_DIR="${DSH_DATA_DIR}/ssh"
SSH_STATE_FILE="${SSH_STATE_DIR}/authorized_keys"
SSH_TARGET_DIR=/home/developer/.ssh
SSH_TARGET_FILE="${SSH_TARGET_DIR}/authorized_keys"

umask 077

install -d -m 0755 /run/sshd
install -d -o developer -g developer -m 0700 "${DSH_DATA_DIR}"
chown -R developer:developer "${DSH_DATA_DIR}"
chmod 0700 "${DSH_DATA_DIR}"
install -d -o developer -g developer -m 0700 "${PNPM_HOME}"
install -d -o developer -g developer -m 0755 /home/developer/workspace
install -d -o developer -g developer -m 0700 "${SSH_STATE_DIR}" "${SSH_TARGET_DIR}"

if [ -n "${SSH_PUB_KEY:-}" ]; then
    SSH_KEY_TEMP="${SSH_STATE_FILE}.tmp"
    printf '%s\n' "${SSH_PUB_KEY}" | tr -d '\r' > "${SSH_KEY_TEMP}"
    chmod 0600 "${SSH_KEY_TEMP}"
    if ! ssh-keygen -l -f "${SSH_KEY_TEMP}" >/dev/null 2>&1; then
        rm -f "${SSH_KEY_TEMP}"
        echo "Invalid SSH_PUB_KEY: expected an OpenSSH public key." >&2
        exit 1
    fi
    chown developer:developer "${SSH_KEY_TEMP}"
    mv "${SSH_KEY_TEMP}" "${SSH_STATE_FILE}"
elif [ ! -s "${SSH_STATE_FILE}" ]; then
    echo "SSH_PUB_KEY is required for the first run or after deleting dsh-data." >&2
    exit 1
fi

install -o developer -g developer -m 0600 "${SSH_STATE_FILE}" "${SSH_TARGET_FILE}"
unset SSH_PUB_KEY

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
