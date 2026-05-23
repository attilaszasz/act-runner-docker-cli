# Use official Docker image to get Docker CLI
FROM docker:27-cli AS docker-cli

# Use official Node.js image to get Node 24 LTS tooling compatible with Alpine
FROM node:24-alpine AS nodejs

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
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    curl -SL "https://github.com/docker/compose/releases/download/v5.0.1/docker-compose-linux-${COMPOSE_ARCH}" \
        -o /root/.docker/cli-plugins/docker-compose && \
    chmod +x /root/.docker/cli-plugins/docker-compose

# Final stage
FROM gitea/runner:1.0.6

# Node.js on Alpine requires the standard C++ runtime.
RUN apk add --no-cache libstdc++

# Copy Docker CLI from official Docker image
COPY --from=docker-cli /usr/local/bin/docker /usr/bin/docker

# Copy Node.js runtime and bundled CLI tools
COPY --from=nodejs /usr/local/bin/node /usr/local/bin/node
COPY --from=nodejs /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf node /usr/local/bin/nodejs && \
    ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

# Copy Docker Compose plugin
COPY --from=build /root/.docker/cli-plugins/docker-compose /root/.docker/cli-plugins/docker-compose

# Verify installations
RUN docker --version && docker compose version && node --version && npm --version