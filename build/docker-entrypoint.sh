#!/bin/sh
set -eu

DSH_DATA_DIR=/data/dsh

install -d -m 0755 /run/sshd
install -d -o developer -g developer -m 0755 "${DSH_DATA_DIR}"
chown -R developer:developer "${DSH_DATA_DIR}"
install -d -o developer -g developer -m 0755 /home/developer/workspace

/usr/sbin/sshd

# dsh 固定监听容器回环地址；由 socat 暴露一个仅供 Docker 端口映射的桥接端口。
socat \
    TCP-LISTEN:3081,bind=0.0.0.0,reuseaddr,fork \
    "TCP:127.0.0.1:${DSH_PORT:-3080}" &

cd /home/developer/.dsh-launcher

exec sudo -u developer -H env \
    CARGO_HOME=/home/developer/.cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH="/home/developer/.cargo/bin:/usr/local/cargo/bin:${PATH}" \
    DSH_HOME="${DSH_DATA_DIR}" \
    DSH_PORT="${DSH_PORT:-3080}" \
    "$@"
