$ErrorActionPreference = 'Stop'

# Resolve the repository root so the script can be run from any PowerShell folder.
$repositoryRoot = Split-Path -Parent $PSScriptRoot
# AZP_IMAGE optionally keeps a custom tag consistent with compose.yaml.
$imageName = if ($env:AZP_IMAGE) { $env:AZP_IMAGE } else { 'azure-devops-self-hosted-agent:local' }

# Docker Desktop selects the host-appropriate Linux architecture automatically.
docker build --tag $imageName $repositoryRoot
