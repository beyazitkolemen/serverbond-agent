# ServerBond Agent Deployment Pipelines

This directory contains an advanced deployment pipeline system for ServerBond Agent, designed to support multiple project types including Laravel, Next.js, Nuxt, WordPress, React, Vue.js, Symfony, Docker, and static projects. The pipeline is built entirely with shell scripts and leverages existing helper scripts located in `/opt/serverbond-agent/scripts`.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Supported Project Types](#supported-project-types)
- [Quick Start](#quick-start)
- [Common Options](#common-options)
- [Project-Specific Options](#project-specific-options)
- [Advanced Features](#advanced-features)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The ServerBond Agent Pipeline system provides a robust, automated deployment solution that handles:

- **Zero-downtime deployments** with atomic releases
- **Automatic rollback** on deployment failures
- **Shared resource management** for persistent data
- **Health checks** and monitoring integration
- **Multi-project support** with type-specific optimizations
- **Notification systems** (Slack, Discord, Email)
- **Parallel deployments** for multiple projects
- **Docker containerization** support

## Architecture

The pipeline follows a modular architecture with a common core (`pipeline.sh`) and project-specific implementations:

```
pipelines/
├── pipeline.sh          # Common pipeline functions and orchestration
├── laravel.sh           # Laravel-specific deployment steps
├── next.sh              # Next.js-specific deployment steps
├── nuxt.sh              # Nuxt.js-specific deployment steps
├── wordpress.sh         # WordPress-specific deployment steps
├── react.sh             # React-specific deployment steps
├── vue.sh               # Vue.js-specific deployment steps
├── symfony.sh           # Symfony-specific deployment steps
├── docker.sh            # Docker-specific deployment steps
└── static.sh            # Static site-specific deployment steps
```

### Pipeline Flow Diagram

```mermaid
graph TD
    A[Pipeline Script] --> B{Project Type}
    
    B -->|Laravel| C[laravel.sh]
    B -->|Next.js| D[next.sh]
    B -->|Nuxt| E[nuxt.sh]
    B -->|WordPress| F[wordpress.sh]
    B -->|React| G[react.sh]
    B -->|Vue| H[vue.sh]
    B -->|Symfony| I[symfony.sh]
    B -->|Docker| J[docker.sh]
    B -->|Static| K[static.sh]
    
    C --> L[Common Pipeline]
    D --> L
    E --> L
    F --> L
    G --> L
    H --> L
    I --> L
    J --> L
    K --> L
    
    L --> M[1. Clone Repository]
    M --> N[2. Copy Environment Files]
    N --> O[3. Project-Specific Build]
    O --> P[4. Setup Shared Resources]
    P --> Q[5. Run Tests]
    Q --> R[6. Activate Release]
    R --> S[7. Health Check]
    S --> T[8. Send Notifications]
    T --> U[9. Run Post-Commands]
    U --> V[10. Cleanup Old Releases]
    
    O --> O1[Composer Install]
    O --> O2[NPM Build]
    O --> O3[Artisan Commands]
    O --> O4[Docker Build]
    O --> O5[Static Generation]
    
    P --> P1[File Resources<br/>file:.env]
    P --> P2[Directory Resources<br/>dir:storage]
    P --> P3[Symlink Creation]
    
    S --> S1{Health Check Pass?}
    S1 -->|Yes| T
    S1 -->|No| S2[Rollback on Failure]
    S2 --> S3[Restore Previous Release]
    
    T --> T1[Slack Notification]
    T --> T2[Discord Notification]
    T --> T3[Email Notification]
```

### Deployment Flow

1. **Repository Cloning** - Shallow or full clone based on configuration
2. **Environment Setup** - Copy environment files and secrets
3. **Project-Specific Build** - Run type-specific build processes
4. **Shared Resources** - Link or copy persistent data
5. **Release Activation** - Atomic switch to new release
6. **Health Verification** - Verify deployment success
7. **Cleanup** - Remove old releases and temporary files

## Supported Project Types

| Project Type | Script | Key Features |
|--------------|--------|--------------|
| **Laravel** | `laravel.sh` | Composer install, Artisan commands, NPM build, migrations, cache management |
| **Next.js** | `next.sh` | NPM build, static export, environment management |
| **Nuxt.js** | `nuxt.sh` | NPM build, generate static, SSR support |
| **WordPress** | `wordpress.sh` | Permission management, shared directories, upload handling |
| **React** | `react.sh` | NPM build, testing, static output |
| **Vue.js** | `vue.sh` | NPM build, testing, static generation |
| **Symfony** | `symfony.sh` | Composer install, cache management, testing |
| **Docker** | `docker.sh` | Image building, container deployment, compose support |
| **Static** | `static.sh` | Build process, static output synchronization |

## Quick Start

### Basic Usage

```bash
# Laravel deployment
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/project.git \
  --branch main \
  --env /secrets/project.env:.env

# Next.js deployment
sudo ./pipelines/next.sh \
  --repo git@github.com:example/next-app.git \
  --branch main \
  --env /secrets/.env.local:.env.local

# Docker deployment
sudo ./pipelines/docker.sh \
  --repo git@github.com:example/docker-app.git \
  --branch main \
  --health-check https://app.example.com/health
```

### Advanced Usage with Rollback

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch main \
  --rollback-on-failure \
  --health-check https://app.example.com/health \
  --webhook https://hooks.slack.com/services/... \
  --notification slack \
  --post-cmd "systemctl reload nginx"
```

## Common Options

All pipeline scripts support these common options:

### Repository and Branch Options

| Option | Description | Default |
|--------|-------------|---------|
| `--repo <URL>` | Git repository URL (required) | - |
| `--branch <BRANCH>` | Git branch to deploy | `main` |
| `--depth <N>` | Shallow clone depth (0 = full clone) | `1` |

### Directory Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `--base-dir <PATH>` | Base deployment directory | `/var/www` |
| `--releases-dir <PATH>` | Custom releases directory | `{base-dir}/releases` |
| `--shared-dir <PATH>` | Custom shared directory | `{base-dir}/shared` |
| `--current-link <PATH>` | Current symlink path | `{base-dir}/current` |

### Release Management

| Option | Description | Default |
|--------|-------------|---------|
| `--keep <N>` | Number of releases to keep | `5` |
| `--no-activate` | Prepare release without activation | `false` |

### Shared Resources

| Option | Description | Example |
|--------|-------------|---------|
| `--shared <PATHS>` | Comma-separated shared paths | `file:.env,dir:storage` |
| `--env <SRC[:TARGET]>` | Environment file mapping | `/secrets/.env:.env` |

### Security and Ownership

| Option | Description | Example |
|--------|-------------|---------|
| `--owner <USER>` | Release directory owner | `www-data` |
| `--group <GROUP>` | Release directory group | `www-data` |

### Advanced Features

| Option | Description | Default |
|--------|-------------|---------|
| `--submodules` | Initialize git submodules | `false` |
| `--rollback-on-failure` | Auto-rollback on failure | `false` |
| `--health-check <URL>` | Post-deployment health check | - |
| `--health-timeout <SEC>` | Health check timeout | `30` |
| `--webhook <URL>` | Notification webhook URL | - |
| `--notification <TYPE>` | Notification type | - |
| `--post-cmd <CMD>` | Post-deployment command | - |

## Project-Specific Options

### Laravel Options

```bash
# Skip specific Laravel steps
--skip-composer          # Skip composer install
--skip-migrate           # Skip artisan migrate
--skip-cache             # Skip cache clearing
--skip-npm               # Skip NPM build

# Force specific Laravel steps
--force-composer         # Force composer install
--force-migrate          # Force artisan migrate
--force-cache            # Force cache clearing
--force-npm              # Force NPM build

# Laravel-specific options
--artisan-seed           # Run migrate with --seed
--npm-script <NAME>      # Custom NPM script (default: build)
--npm-skip-install       # Skip npm install step
--run-tests              # Run php artisan test
--tests "COMMAND"        # Custom test command
```

### Next.js Options

```bash
--skip-npm               # Skip NPM build
--force-npm              # Force NPM build
--npm-script <NAME>      # Custom NPM script (default: build)
--npm-skip-install       # Skip npm install
--run-tests              # Run npm test
--tests "COMMAND"        # Custom test command
```

### WordPress Options

```bash
--skip-wp-permissions    # Skip WordPress permission setup
--wp-permissions         # Force WordPress permission setup
```

### Static Site Options

```bash
--static-build <NAME>    # Run npm run <NAME> for static build
--static-output <PATH>   # Sync build output to shared directory
```

### Docker Options

Docker pipelines use only common options. They automatically detect and handle:
- `docker-compose.yml` files for compose-based deployments
- `Dockerfile` for single-container deployments
- Environment file management
- Container lifecycle management

## Advanced Features

### Shared Resource Management

The pipeline supports two types of shared resources:

#### File Resources (`file:` prefix)
```bash
--shared "file:.env,file:config.json"
```
- Files are stored in the shared directory
- Symlinked to the release directory
- Useful for configuration files and secrets

#### Directory Resources (`dir:` prefix)
```bash
--shared "dir:storage,dir:uploads,dir:cache"
```
- Directories are copied to shared directory
- Symlinked to the release directory
- Useful for persistent data and uploads

### Environment File Management

```bash
# Single environment file
--env /secrets/production.env:.env

# Multiple environment files
--env /secrets/.env:.env
--env /secrets/.env.local:.env.local
--env /secrets/database.env:.env.database
```

### Health Check System

```bash
# Basic health check
--health-check https://app.example.com/health

# With custom timeout
--health-check https://api.example.com/status --health-timeout 60

# With rollback on failure
--health-check https://app.example.com/health --rollback-on-failure
```

### Notification System

#### Slack Notifications
```bash
--webhook https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
--notification slack
```

#### Discord Notifications
```bash
--webhook https://discord.com/api/webhooks/000000000000000000/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
--notification discord
```

#### Email Notifications
```bash
--webhook https://api.sendgrid.com/v3/mail/send
--notification email
```

### Post-Deployment Commands

```bash
# Single command
--post-cmd "systemctl reload nginx"

# Multiple commands
--post-cmd "systemctl reload nginx"
--post-cmd "systemctl restart php8.1-fpm"
--post-cmd "redis-cli FLUSHALL"
```

### Parallel Deployments

Deploy multiple projects simultaneously:

```bash
# Using configuration file
sudo ./pipelines/parallel.sh --config deployments.conf --max-parallel 3

# Using command line
sudo ./pipelines/parallel.sh --deploy "laravel:git@github.com:user/app.git:main:--env /secrets/.env"
```

Configuration file format (`deployments.conf`):
```
laravel:git@github.com:user/laravel-app.git:main:--env /secrets/.env
react:git@github.com:user/react-app.git:develop:--run-tests
docker:git@github.com:user/docker-app.git:main:--health-check https://app.example.com/health
```

## Examples

### Laravel E-commerce Application

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:company/ecommerce.git \
  --branch production \
  --env /secrets/production.env:.env \
  --shared "file:.env,dir:storage,dir:bootstrap/cache,dir:public/storage" \
  --artisan-seed \
  --run-tests \
  --health-check https://shop.company.com/health \
  --rollback-on-failure \
  --webhook https://hooks.slack.com/services/... \
  --notification slack \
  --post-cmd "systemctl reload nginx" \
  --post-cmd "systemctl restart php8.1-fpm" \
  --owner www-data \
  --group www-data
```

### Next.js Blog with Static Export

```bash
sudo ./pipelines/next.sh \
  --repo git@github.com:blog/nextjs-blog.git \
  --branch main \
  --env /secrets/.env.local:.env.local \
  --shared "file:.env.local" \
  --npm-script "build" \
  --run-tests \
  --health-check https://blog.example.com \
  --webhook https://discord.com/api/webhooks/... \
  --notification discord
```

### WordPress Multisite

```bash
sudo ./pipelines/wordpress.sh \
  --repo git@github.com:company/wordpress-multisite.git \
  --branch production \
  --env /secrets/wp-config.php:wp-config.php \
  --shared "file:wp-config.php,dir:wp-content/uploads,dir:wp-content/cache" \
  --wp-permissions \
  --health-check https://network.company.com \
  --post-cmd "systemctl reload nginx"
```

### Docker Microservices

```bash
sudo ./pipelines/docker.sh \
  --repo git@github.com:company/microservices.git \
  --branch main \
  --env /secrets/.env:.env \
  --shared "file:.env,file:docker-compose.yml" \
  --health-check https://api.company.com/health \
  --rollback-on-failure \
  --post-cmd "docker system prune -f"
```

### Static Site with Build Process

```bash
sudo ./pipelines/static.sh \
  --repo git@github.com:company/static-site.git \
  --branch main \
  --static-build "build" \
  --static-output "dist" \
  --health-check https://site.company.com
```

## Troubleshooting

### Common Issues

#### Permission Denied Errors
```bash
# Ensure proper ownership
sudo ./pipelines/laravel.sh --owner www-data --group www-data

# Check directory permissions
ls -la /var/www/
```

#### Git Clone Failures
```bash
# Check repository access
git ls-remote git@github.com:user/repo.git

# Use HTTPS instead of SSH
--repo https://github.com/user/repo.git
```

#### Health Check Failures
```bash
# Test health check manually
curl -f https://app.example.com/health

# Increase timeout
--health-timeout 60
```

#### NPM Build Failures
```bash
# Skip NPM if not needed
--skip-npm

# Use custom script
--npm-script "build:production"
```

#### Database Migration Issues
```bash
# Skip migrations for testing
--skip-migrate

# Force migrations
--force-migrate
```

### Debug Mode

Enable verbose logging by setting environment variables:

```bash
export DEBUG=1
export VERBOSE=1
sudo ./pipelines/laravel.sh --repo ...
```

### Log Files

Pipeline logs are written to:
- `/var/log/serverbond-agent/pipeline.log`
- `/var/log/serverbond-agent/deploy.log`

### Rollback Procedures

#### Manual Rollback
```bash
# List available releases
ls -la /var/www/releases/

# Switch to previous release
ln -sfn /var/www/releases/20231201120000 /var/www/current
```

#### Automatic Rollback
```bash
# Enable automatic rollback
--rollback-on-failure
```

## Best Practices

### Security

1. **Use environment files for secrets**:
   ```bash
   --env /secrets/production.env:.env
   ```

2. **Set proper ownership**:
   ```bash
   --owner www-data --group www-data
   ```

3. **Use shallow clones for large repositories**:
   ```bash
   --depth 1
   ```

### Performance

1. **Keep only necessary releases**:
   ```bash
   --keep 3
   ```

2. **Use shared resources for persistent data**:
   ```bash
   --shared "dir:storage,dir:uploads"
   ```

3. **Skip unnecessary steps**:
   ```bash
   --skip-tests  # In production
   --skip-npm    # If not needed
   ```

### Monitoring

1. **Always use health checks**:
   ```bash
   --health-check https://app.example.com/health
   ```

2. **Enable notifications**:
   ```bash
   --webhook https://hooks.slack.com/... --notification slack
   ```

3. **Use rollback protection**:
   ```bash
   --rollback-on-failure
   ```

### Maintenance

1. **Regular cleanup**:
   ```bash
   --keep 5  # Keep only 5 releases
   ```

2. **Post-deployment tasks**:
   ```bash
   --post-cmd "systemctl reload nginx"
   ```

3. **Monitor disk space**:
   ```bash
   df -h /var/www/
   ```

## Directory Structure

After deployment, the following structure is created:

```
/var/www/
├── current -> releases/20231201120000/    # Symlink to active release
├── releases/                              # All releases
│   ├── 20231201120000/                   # Timestamped release
│   ├── 20231201110000/
│   └── ...
└── shared/                               # Shared resources
    ├── .env                              # Environment files
    ├── storage/                          # Persistent data
    └── uploads/                          # User uploads
```

## Requirements

- **Operating System**: Linux (Ubuntu 20.04+, CentOS 7+, Debian 10+)
- **Permissions**: Root access required
- **Dependencies**: Git, Bash 4.0+
- **Project Dependencies**: Varies by project type (Node.js, PHP, Docker, etc.)

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review log files in `/var/log/serverbond-agent/`
3. Enable debug mode with `DEBUG=1`
4. Consult the ServerBond Agent documentation

---

**Note**: This pipeline system requires root privileges and should be used in secure, controlled environments. Always test deployments in staging environments before production use.