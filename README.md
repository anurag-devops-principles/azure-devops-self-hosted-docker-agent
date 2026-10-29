# Azure DevOps self-hosted Docker agent

One repository can use two agents: one on a Windows PC and one on a MacBook. Each computer runs the same Linux Docker image but registers a separate Azure DevOps agent. They can share a pool; their agent names must be unique.

The image supports Linux `amd64` (typical Windows Docker Desktop host) and `arm64` (Apple Silicon MacBook) automatically. Docker Desktop must be running on each computer and configured for Linux containers.

> This is a **Linux container agent** on both computers. It can use the host Docker daemon, but jobs run Linux tools from this image. For native Windows applications, or Mac-only tooling such as Xcode, install a separate native Azure Pipelines agent on that operating system instead.

## Step-by-step setup

### 1. Prerequisites

Complete these items on **both** the Windows computer and the MacBook:

1. Install Docker Desktop and start it.
2. In Docker Desktop settings, use **Linux containers**. (This is the default on macOS.)
3. Confirm Docker is working:

   ```bash
   docker version
   docker compose version
   ```

4. Clone this repository onto the computer.

### 2. Create an Azure DevOps agent pool

You only need to do this once for the Azure DevOps organization:

1. Open Azure DevOps in a browser.
2. Go to **Organization settings** → **Agent pools**.
3. Either use the existing `Default` pool, or select **Add pool** and create one, for example `Docker-Agents`.
4. Remember the pool name. Both computers can use this same pool.

### 3. Create a Personal Access Token (PAT)

1. In Azure DevOps, select **User settings** → **Personal access tokens**.
2. Select **New Token**.
3. Give it a clear name, such as `docker-self-hosted-agent`.
4. Select your organization and an appropriate expiry date.
5. Under scopes, set **Agent Pools** to **Read & manage**.
6. Create the token and copy it immediately. Azure DevOps only shows the token value once.

Treat this token as a password. Do not commit it or paste it into a pipeline YAML file.

### 4. Configure the Windows agent

In PowerShell, from the repository directory:

```powershell
Copy-Item .env.example .env
notepad .env
```

Set the values in `.env`. Replace the example organization and token:

```env
AZP_URL=https://dev.azure.com/your-organization
AZP_TOKEN=your-personal-access-token
AZP_POOL=Docker-Agents
AZP_AGENT_NAME=windows-docker-agent
```

Build and start the container:

```powershell
.\scripts\build.ps1
docker compose up -d
```

### 5. Configure the MacBook agent

In Terminal, from the repository directory:

```bash
cp .env.example .env
${EDITOR:-nano} .env
```

Set the same organization URL, token, and pool, but use a different agent name:

```env
AZP_URL=https://dev.azure.com/your-organization
AZP_TOKEN=your-personal-access-token
AZP_POOL=Docker-Agents
AZP_AGENT_NAME=macbook-docker-agent
```

Build and start the container:

```bash
chmod +x scripts/build.sh start.sh bootstrap.sh
./scripts/build.sh
docker compose up -d
```

### 6. Verify both agents are online

On either computer, view container logs:

```bash
docker compose logs -f
```

Look for `Starting Azure DevOps agent`. Then in Azure DevOps go to **Organization settings** → **Agent pools** → your pool. You should see both `windows-docker-agent` and `macbook-docker-agent` with status **Online**.

Use `Ctrl+C` to stop following the logs; the agent container keeps running in the background.

## Targeting the agents in a pipeline

Use the pool name in Azure Pipelines. This lets Azure DevOps dispatch a queued job to either available computer:

```yaml
pool:
  name: Docker-Agents
```

To pin a job to one computer, add a demand using its agent name:

```yaml
pool:
  name: Docker-Agents
  demands:
    - Agent.Name -equals macbook-docker-agent
```

The agent can run `docker` commands through the host Docker Desktop daemon. Treat pipelines that use this pool as trusted: mounting the Docker socket gives jobs powerful access to that host.

## Daily commands and maintenance

- Stop without removing the registration: `docker compose stop`.
- Follow logs: `docker compose logs -f`.
- Rebuild after changing the Dockerfile: `docker compose build --no-cache` then `docker compose up -d`.
- Restart an agent: `docker compose restart`.
- To remove the container and its local work cache: `docker compose down -v`. The next `docker compose up -d` re-registers it using the configured agent name.
