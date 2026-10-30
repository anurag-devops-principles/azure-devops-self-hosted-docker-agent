
#!/usr/bin/env bash
set -Eeuo pipefail

# The Azure Pipelines agent files, including config.sh and run.sh, live here.
cd /azp

# Fail before registration if the required secrets/configuration were not supplied.
: "${AZP_URL:?Set AZP_URL in your .env file}"
: "${AZP_TOKEN:?Set AZP_TOKEN in your .env file}"

# A pool can be shared, but every concurrently running agent needs its own name.
AZP_POOL="${AZP_POOL:-Default}"
: "${AZP_AGENT_NAME:?Set a unique AZP_AGENT_NAME for this computer}"

# .agent is created by config.sh. A normal container restart retains it and
# therefore does not re-register the agent.
if [[ ! -f .agent ]]; then
    echo "Registering agent: ${AZP_AGENT_NAME}"

    # --replace safely recovers the same agent name after an unclean container stop.
    ./config.sh \
        --unattended \
        --url "${AZP_URL}" \
        --auth pat \
        --token "${AZP_TOKEN}" \
        --pool "${AZP_POOL}" \
        --agent "${AZP_AGENT_NAME}" \
        --replace \
        --acceptTeeEula
else
    echo "Existing agent configuration found."
fi

# Print installed versions once at startup to make troubleshooting job failures easier.
echo "===== Agent tool inventory ====="
terraform version
tflint --version
docker --version
az version
helm version
git --version
mvn -version
node --version
npm --version
python3 --version
sonar-scanner --version

# exec passes signals directly to the agent process, allowing Docker to stop it cleanly.
echo "===== Starting Azure DevOps agent ====="
exec ./run.sh
