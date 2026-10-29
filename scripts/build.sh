#!/usr/bin/env bash
set -Eeuo pipefail

# Resolve the repository root so the script can be run from any Terminal folder.
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# AZP_IMAGE optionally keeps a custom tag consistent with compose.yaml.
image_name="${AZP_IMAGE:-azure-devops-self-hosted-agent:local}"

# Docker Desktop selects the host-appropriate Linux architecture automatically.
docker build --tag "${image_name}" "${repository_root}"
