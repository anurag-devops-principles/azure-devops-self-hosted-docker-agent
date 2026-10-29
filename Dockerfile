
# Azure DevOps Self-Hosted Agent
# Multi-platform: Linux AMD64 and ARM64

FROM debian:bookworm-slim

ARG TARGETARCH
ARG TERRAFORM_VERSION=1.12.2
ARG TFLINT_VERSION=0.58.0
ARG KUBECTL_VERSION=v1.32.0
ARG HELM_VERSION=v3.17.1
ARG AZP_AGENT_VERSION=4.268.0
ARG SONAR_SCANNER_VERSION=8.0.1.6346

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/sonar-scanner/bin:${PATH}"

USER root
WORKDIR /azp

# 1. Common dependencies and Java runtimes
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget unzip tar gzip git jq gnupg \
      lsb-release apt-transport-https bash procps \
      libicu72 libkrb5-3 zlib1g \
      openjdk-17-jdk-headless maven \
      nodejs npm python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*

# 2. Docker CLI (daemon is provided by Docker Desktop)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
      -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# 3. Terraform
RUN curl -fsSLo /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" && \
    unzip /tmp/terraform.zip -d /usr/local/bin && \
    rm /tmp/terraform.zip && \
    terraform version

# 4. Azure CLI
RUN curl -fsSL https://aka.ms/InstallAzureCLIDeb \
      -o /tmp/install-azure-cli.sh && \
    bash /tmp/install-azure-cli.sh && \
    rm -f /tmp/install-azure-cli.sh && \
    rm -rf /var/lib/apt/lists/* && \
    az version

# 5. kubectl
RUN curl --retry 5 --retry-delay 2 -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    chmod +x /usr/local/bin/kubectl && \
    kubectl version --client

# 6. Helm
RUN curl -fsSLo /tmp/helm.tar.gz \
      "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" && \
    tar -xzf /tmp/helm.tar.gz -C /tmp && \
    install -m 0755 "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm && \
    rm -rf /tmp/helm.tar.gz "/tmp/linux-${TARGETARCH}" && \
    helm version

# 7. TFLint
RUN curl -fsSLo /tmp/tflint.zip \
      "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${TARGETARCH}.zip" && \
    unzip /tmp/tflint.zip -d /usr/local/bin && \
    rm /tmp/tflint.zip && \
    tflint --version

# 8. SonarScanner CLI
RUN set -eux; \
    if [ "${TARGETARCH}" = "amd64" ]; then \
      SONAR_ARCH="x64"; \
    elif [ "${TARGETARCH}" = "arm64" ]; then \
      SONAR_ARCH="aarch64"; \
    else \
      echo "Unsupported architecture: ${TARGETARCH}"; exit 1; \
    fi; \
    curl -fsSLo /tmp/sonar-scanner.zip \
      "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-${SONAR_ARCH}.zip"; \
    unzip /tmp/sonar-scanner.zip -d /opt; \
    mv "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-${SONAR_ARCH}" /opt/sonar-scanner; \
    ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner; \
    rm /tmp/sonar-scanner.zip; \
    sonar-scanner --version

# 9. Azure DevOps agent
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) AZP_ARCH="x64" ;; \
      arm64) AZP_ARCH="arm64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSLo /tmp/azp-agent.tar.gz \
      "https://download.agent.dev.azure.com/agent/${AZP_AGENT_VERSION}/vsts-agent-linux-${AZP_ARCH}-${AZP_AGENT_VERSION}.tar.gz"; \
    tar -xzf /tmp/azp-agent.tar.gz -C /azp; \
    rm /tmp/azp-agent.tar.gz

# 10. Non-root user
RUN useradd --create-home --shell /bin/bash azp && \
    chown -R azp:azp /azp

COPY --chown=azp:azp start.sh /azp/start.sh
COPY bootstrap.sh /azp/bootstrap.sh
RUN chmod 0755 /azp/start.sh /azp/bootstrap.sh

# bootstrap.sh starts as root only to map the mounted Docker socket's group,
# then drops privileges to azp before registering or running the agent.
USER root
WORKDIR /azp

ENTRYPOINT ["./bootstrap.sh"]
