# Use official Docker image to get Docker CLI
FROM docker:27-cli AS docker-cli

# Build stage for Docker Compose
FROM ubuntu:24.04 AS build

# Install dependencies and download Docker Compose
RUN apt-get update -yq && \
    apt-get install -yq --no-install-recommends curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /root/.docker/cli-plugins && \
    ARCH=$(uname -m) && \
    case ${ARCH} in \
        x86_64) COMPOSE_ARCH=x86_64 ;; \
        aarch64|arm64) COMPOSE_ARCH=aarch64 ;; \
        armv7l) COMPOSE_ARCH=armv7 ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    curl -SL "https://github.com/docker/compose/releases/download/v5.0.1/docker-compose-linux-${COMPOSE_ARCH}" \
        -o /root/.docker/cli-plugins/docker-compose && \
    chmod +x /root/.docker/cli-plugins/docker-compose

# Final stage
FROM gitea/act_runner:0.2.13

# Copy Docker CLI from official Docker image
COPY --from=docker-cli /usr/local/bin/docker /usr/bin/docker

# Copy Docker Compose plugin
COPY --from=build /root/.docker/cli-plugins/docker-compose /root/.docker/cli-plugins/docker-compose

# Verify installations
RUN docker --version && docker compose version