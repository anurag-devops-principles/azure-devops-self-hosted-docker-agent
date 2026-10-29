#!/usr/bin/env bash
set -Eeuo pipefail

# Docker Desktop commonly exposes the socket with a host-specific numeric GID.
# Add the unprivileged agent account to that group before starting the agent.
if [[ -S /var/run/docker.sock ]]; then
    socket_gid="$(stat -c '%g' /var/run/docker.sock)"
    socket_group="$(getent group "${socket_gid}" | cut -d: -f1 || true)"

    if [[ -z "${socket_group}" ]]; then
        socket_group="docker-host"
        groupadd --gid "${socket_gid}" "${socket_group}"
    fi

    usermod --append --groups "${socket_group}" azp
fi

# The agent itself never runs as root. Preserve AZP_* values from Docker Compose.
exec runuser --preserve-environment --user azp -- /azp/start.sh
