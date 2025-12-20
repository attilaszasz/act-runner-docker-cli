# act-runner-docker-cli

A Docker image based on [Gitea Act Runner](https://gitea.com/gitea/act_runner) with Docker CLI and Docker Compose pre-installed, enabling your CI/CD workflows to build, run, and manage Docker containers and compose projects.

## Features

- **Base Image**: `gitea/act_runner:0.2.13`
- **Docker CLI**: Latest version from official Docker image (`docker:27-cli`)
- **Docker Compose**: v5.0.1 (installed as a Docker CLI plugin)
- **Multi-Architecture Support**: Available for `linux/amd64` and `linux/arm64`
- **Lightweight**: Optimized build with minimal layers and cleaned package caches

## Supported Architectures

This image supports the following platforms:

- `linux/amd64` (x86_64)
- `linux/arm64` (aarch64)

Docker automatically pulls the correct architecture for your system.

## Quick Start

### Using Docker Run

```bash
docker run -d \
  --name gitea-runner \
  -e GITEA_INSTANCE_URL="https://your-gitea-instance.com" \
  -e GITEA_RUNNER_REGISTRATION_TOKEN="your-registration-token" \
  -e GITEA_RUNNER_NAME="my-runner" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ./runner-data:/data \
  ghcr.io/attilaszasz/act-runner-docker-cli:latest
```

### Using Docker Compose

Create a `docker-compose.yml` file:

```yaml
networks:
  gitea:
    external: true

services:
  gitea:
    image: docker.gitea.com/gitea:latest
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    networks:
      - gitea
    volumes:
      - ./gitea/data:/data
      - /etc/TZ:/etc/TZ:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - 3000:3000
      - 222:22

  runner:
    image: ghcr.io/attilaszasz/act-runner-docker-cli:latest
    container_name: gitea-runner
    environment:
      GITEA_INSTANCE_URL: "https://gitea.example.com"
      GITEA_RUNNER_REGISTRATION_TOKEN: "your-token-here"
      GITEA_RUNNER_NAME: "my-runner"
      # Optional: Custom labels
      # GITEA_RUNNER_LABELS: "ubuntu-latest:docker://node:20-bullseye,ubuntu-22.04:docker://node:20-bullseye"
    restart: always
    depends_on:
      - gitea
    networks:
      - gitea
    volumes:
      - ./gitea/runner:/data
      - /var/run/docker.sock:/var/run/docker.sock
```

Then start the services:

```bash
docker-compose up -d
```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITEA_INSTANCE_URL` | URL of your Gitea instance | `https://gitea.example.com` |
| `GITEA_RUNNER_REGISTRATION_TOKEN` | Runner registration token from Gitea | Obtained from Gitea Admin → Actions → Runners |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GITEA_RUNNER_NAME` | Display name for the runner | Auto-generated |
| `GITEA_RUNNER_LABELS` | Custom runner labels for job targeting | Default labels from base image |

### Getting the Registration Token

1. Log in to your Gitea instance as an administrator
2. Navigate to **Site Administration** → **Actions** → **Runners**
3. Click **Create new Runner** 
4. Copy the registration token displayed
5. Use this token in the `GITEA_RUNNER_REGISTRATION_TOKEN` environment variable

## Volume Mounts

### Required Mounts

- **Docker Socket**: `/var/run/docker.sock:/var/run/docker.sock`
  - Allows the runner to communicate with the Docker daemon
  - **Important**: This grants the container full control over your Docker host
  
- **Data Directory**: `./runner-data:/data`
  - Stores runner configuration and state
  - Persists across container restarts

### Optional Mounts

- **Timezone**: `/etc/TZ:/etc/TZ:ro` and `/etc/localtime:/etc/localtime:ro`
  - Synchronizes container timezone with host

## Runner Labels

Runner labels determine which jobs the runner can execute. You can customize labels using the `GITEA_RUNNER_LABELS` environment variable:

```yaml
GITEA_RUNNER_LABELS: "ubuntu-latest:docker://node:20-bullseye,ubuntu-22.04:docker://catthehacker/ubuntu:act-22.04"
```

### Label Format

```
label-name:docker://image-name
```

- **label-name**: The label used in workflow files (`runs-on: label-name`)
- **image-name**: The Docker image to use for jobs with this label

### Example Workflow

```yaml
name: CI
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build Docker image
        run: docker build -t myapp .
      
      - name: Run with Docker Compose
        run: docker compose up -d
```

## Security Considerations

### Docker Socket Access

This image requires access to the Docker socket (`/var/run/docker.sock`), which grants **full control** over the Docker daemon. Consider the following:

1. **Trusted Workflows Only**: Only run workflows you trust
2. **Isolated Network**: Use a dedicated Docker network for the runner
3. **Resource Limits**: Set memory and CPU limits in your compose file:

```yaml
services:
  runner:
    # ... other config ...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
```

4. **Rootless Docker**: For improved security, consider using rootless Docker mode
5. **Private Repositories**: Restrict runner access to private repositories only

## Troubleshooting

### Runner Not Connecting

1. **Check Network**: Ensure the runner can reach `GITEA_INSTANCE_URL`
   ```bash
   docker exec gitea-runner curl -I https://your-gitea-instance.com
   ```

2. **Verify Token**: Check that `GITEA_RUNNER_REGISTRATION_TOKEN` is correct

3. **Check Logs**:
   ```bash
   docker logs gitea-runner
   ```

### Docker Commands Failing in Workflows

1. **Verify Socket Mount**: Ensure `/var/run/docker.sock` is mounted
   ```bash
   docker exec gitea-runner ls -l /var/run/docker.sock
   ```

2. **Check Permissions**: The runner needs access to the Docker socket

3. **Test Docker Access**:
   ```bash
   docker exec gitea-runner docker ps
   ```

### Compose Commands Not Found

Verify Docker Compose is installed correctly:
```bash
docker exec gitea-runner docker compose version
```

Should output: `Docker Compose version v5.0.1`

## GitOps for Homelab

This runner is perfect for implementing GitOps-style continuous deployment in your homelab. Push changes to your Git repository, and automatically deploy your services to your homelab server.

### How It Works

1. **Push to Git**: Commit and push changes to your Gitea repository
2. **Trigger Workflow**: Gitea Actions automatically runs your deployment workflow
3. **Deploy Services**: The runner executes `docker compose` commands on your homelab host
4. **Automatic Updates**: Your services are updated without manual intervention

### Complete Setup Guide

#### 1. Repository Structure

Organize your infrastructure repository:

```
homelab/
├── .gitea/
│   └── workflows/
│       └── deploy.yml
├── docker-compose.yml
├── .env.example
└── README.md
```

#### 2. Create Deployment Workflow

Create `.gitea/workflows/deploy.yml`:

```yaml
name: Deploy to Homelab

on:
  push:
    branches:
      - main

jobs:
  deploy:
    # Target your specific runner using custom labels
    runs-on: [ubuntu-22.04, homelab]

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Create .env file from secrets
        run: |
          echo "TZ=${{ vars.TZ }}" > .env
          echo "PUID=${{ vars.PUID }}" >> .env
          echo "PGID=${{ vars.PGID }}" >> .env
          echo "DOMAIN=${{ vars.DOMAIN }}" >> .env
          echo "DB_PASSWORD=${{ secrets.DB_PASSWORD }}" >> .env
          echo "API_KEY=${{ secrets.API_KEY }}" >> .env

      - name: Deploy services
        run: docker compose up -d --remove-orphans

      - name: Clean up old images
        run: docker image prune -af --filter "until=72h"
```

#### 3. Configure Runner Labels

Set a custom label to target your homelab runner specifically. In your docker-compose.yml:

```yaml
runner:
  image: ghcr.io/attilaszasz/act-runner-docker-cli:latest
  environment:
    GITEA_INSTANCE_URL: "https://gitea.example.com"
    GITEA_RUNNER_REGISTRATION_TOKEN: "your-token-here"
    GITEA_RUNNER_NAME: "homelab-runner"
    # Add custom label to identify this runner
    GITEA_RUNNER_LABELS: "ubuntu-22.04:docker://catthehacker/ubuntu:act-22.04,homelab:host"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - ./runner-data:/data
```

**Label Explanation**:
- `ubuntu-22.04:docker://...` - Run jobs in a Docker container
- `homelab:host` - Run jobs directly on the host (necessary for docker compose deployments)

#### 4. Set Up Repository Variables and Secrets

In Gitea, navigate to your repository → **Settings** → **Actions** → **Secrets and Variables**

**Variables** (non-sensitive configuration):
```
TZ=America/New_York
PUID=1000
PGID=1000
DOMAIN=example.com
```

**Secrets** (sensitive data):
```
DB_PASSWORD=your-secure-password
API_KEY=your-api-key
NOTIFICATION_TOKEN=your-token
```

#### 5. Example Docker Compose File

Your `docker-compose.yml` in the repository:

```yaml
version: '3.8'

services:
  app:
    image: myapp:latest
    container_name: myapp
    environment:
      - TZ=${TZ}
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - ./data:/data
    ports:
      - "8080:8080"
    restart: unless-stopped

  db:
    image: postgres:16
    container_name: myapp-db
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - ./postgres:/var/lib/postgresql/data
    restart: unless-stopped
```

### Advanced Workflow Examples

#### Multi-Environment Deployment

Deploy to different environments based on branches:

```yaml
name: Deploy

on:
  push:
    branches:
      - main
      - staging

jobs:
  deploy:
    runs-on: [ubuntu-22.04, homelab]

    steps:
      - uses: actions/checkout@v4

      - name: Set environment
        run: |
          if [ "${{ github.ref }}" == "refs/heads/main" ]; then
            echo "ENV=production" >> $GITHUB_ENV
            echo "COMPOSE_FILE=docker-compose.yml" >> $GITHUB_ENV
          else
            echo "ENV=staging" >> $GITHUB_ENV
            echo "COMPOSE_FILE=docker-compose.staging.yml" >> $GITHUB_ENV
          fi

      - name: Deploy to ${{ env.ENV }}
        run: docker compose -f ${{ env.COMPOSE_FILE }} up -d
```

#### Health Checks and Notifications

```yaml
name: Deploy with Monitoring

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: [ubuntu-22.04, homelab]

    steps:
      - uses: actions/checkout@v4

      - name: Deploy services
        run: docker compose up -d --remove-orphans

      - name: Wait for services to be healthy
        run: |
          echo "Waiting for services to be healthy..."
          timeout 60 docker compose ps | grep -q "(healthy)" || exit 1

      - name: Send success notification
        if: success()
        run: |
          curl -X POST "${{ secrets.GOTIFY_URL }}/message?token=${{ secrets.GOTIFY_TOKEN }}" \
            -F "title=Deployment Success" \
            -F "message=Services deployed successfully to homelab" \
            -F "priority=5"

      - name: Send failure notification
        if: failure()
        run: |
          curl -X POST "${{ secrets.GOTIFY_URL }}/message?token=${{ secrets.GOTIFY_TOKEN }}" \
            -F "title=Deployment Failed" \
            -F "message=Deployment to homelab failed. Check logs." \
            -F "priority=10"
```

#### Backup Before Deploy

```yaml
name: Deploy with Backup

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: [ubuntu-22.04, homelab]

    steps:
      - uses: actions/checkout@v4

      - name: Backup current state
        run: |
          mkdir -p backups
          docker compose config > backups/compose-$(date +%Y%m%d-%H%M%S).yml
          docker compose ps > backups/services-$(date +%Y%m%d-%H%M%S).txt

      - name: Deploy services
        run: docker compose up -d --remove-orphans

      - name: Rollback on failure
        if: failure()
        run: |
          echo "Deployment failed, rolling back..."
          docker compose down
          # Restore previous version here if needed
```

### Best Practices for Homelab GitOps

1. **Version Control Everything**
   - Store all configuration in Git
   - Use `.env.example` with dummy values (commit this)
   - Never commit `.env` with real secrets (add to `.gitignore`)

2. **Use Repository Secrets**
   - Store sensitive data in Gitea's secret manager
   - Reference secrets in workflows, not in compose files
   - Rotate secrets regularly

3. **Test Before Deploying**
   - Use separate staging environments when possible
   - Validate compose files: `docker compose config`
   - Test workflows on feature branches

4. **Monitor and Log**
   - Set up notifications for deployment status
   - Keep deployment logs
   - Monitor service health after deployment

5. **Backup Strategy**
   - Backup volumes before updates
   - Store backups outside the deployment directory
   - Test restore procedures regularly

6. **Network Security**
   - Use dedicated Docker networks
   - Limit runner access to necessary resources
   - Keep runner on isolated network segment if possible

7. **Documentation**
   - Document your workflow in repository README
   - Keep track of dependencies
   - Document rollback procedures

### Troubleshooting GitOps Deployments

**Workflow not triggering:**
- Verify Actions are enabled in repository settings
- Check that workflow file is in `.gitea/workflows/` directory
- Ensure YAML syntax is correct

**Runner not picking up jobs:**
- Verify runner labels match `runs-on` in workflow
- Check runner is connected: `docker logs gitea-runner`
- Ensure runner has necessary permissions

**Deployment fails with permission errors:**
- Check Docker socket permissions
- Verify PUID/PGID values are correct
- Ensure directories exist and are writable

**Services don't update:**
- Force recreate: `docker compose up -d --force-recreate`
- Check if images are pulled: add `docker compose pull` step
- Verify compose file changes are committed

## Building from Source

Clone the repository and build the image:

```bash
git clone https://github.com/attilaszasz/act-runner-docker-cli.git
cd act-runner-docker-cli
docker build -t act-runner-docker-cli .
```

### Multi-Architecture Build

To build for multiple architectures:

```bash
docker buildx create --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/attilaszasz/act-runner-docker-cli:latest \
  --push .
```

## Version Information

- **Act Runner**: 0.2.13
- **Docker CLI**: 27
- **Docker Compose**: 5.0.1
- **Base OS**: Ubuntu 24.04 LTS (build stage)

## Updates

To update to the latest version:

```bash
docker pull ghcr.io/attilaszasz/act-runner-docker-cli:latest
docker-compose up -d
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project builds upon the official Gitea Act Runner. See the [Gitea Act Runner repository](https://gitea.com/gitea/act_runner) for license information.

## Related Projects

- [Gitea](https://gitea.com) - Self-hosted Git service
- [Gitea Act Runner](https://gitea.com/gitea/act_runner) - Official Gitea Actions runner

## Support

- **Issues**: [GitHub Issues](https://github.com/attilaszasz/act-runner-docker-cli/issues)
- **Gitea Actions Documentation**: [docs.gitea.com](https://docs.gitea.com/usage/actions/overview)
