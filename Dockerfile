FROM ubuntu:24.04 as build

# Install Docker CLI
RUN apt-get update -yq
RUN apt-get install -yq curl ca-certificates
RUN apt-get install -y docker.io

# Install Docker Compose
RUN mkdir -p /root/.docker/cli-plugins
RUN curl -SL https://github.com/docker/compose/releases/download/v5.0.1/docker-compose-linux-x86_64 -o /root/.docker/cli-plugins/docker-compose
RUN chmod +x /root/.docker/cli-plugins/docker-compose

FROM gitea/act_runner:0.2.13

# Copy Docker CLI and Docker Compose from build image
COPY --from=build /root/.docker /root/.docker
COPY --from=docker:latest /usr/local/bin/docker /usr/bin/docker