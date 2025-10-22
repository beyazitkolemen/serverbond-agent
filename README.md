# ServerBond Agent

Modern, fast and easy server management platform. Get your Ubuntu 24.04 server ready for Laravel hosting with a single command.

## 🚀 Installation

```bash
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

When installation is complete:
- ✅ ServerBond Panel is automatically installed
- ✅ Nginx, PHP 8.4, MySQL, Redis are ready
- ✅ You can access the panel at http://SERVER_IP

## 🔐 Panel Login

```
URL      : http://SERVER_IP/
Email    : admin@serverbond.local
Password : password
```

> ⚠️ Change your password on first login!

## 📦 What Gets Installed?

- **ServerBond Panel** - Web-based management panel (Filament 4)
- **Nginx** - Web server
- **PHP 8.4** - Modern PHP runtime
- **MySQL 8.0** - Database
- **Redis** - Cache system
- **Node.js 20** - JavaScript runtime
- **Python 3.12** - Python runtime
- **Certbot** - SSL certificate manager
- **Supervisor** - Process manager
- **Docker** (Optional) - Container management
- **Cloudflared** (Optional) - Cloudflare Tunnel support

## 📋 Requirements

- Ubuntu 24.04 LTS
- Root privileges
- Internet connection
- At least 5GB disk space

## 🎯 Features

- Multi-site management
- Laravel, PHP, Static, Node.js, Python support
- Automatic Git deployment
- SSL/TLS management
- Database management
- Real-time monitoring

## 🐳 Docker Installation (Optional)

Advanced container management with Docker:

```bash
# Basic Docker installation
sudo ./opt/serverbond-agent/scripts/install-docker.sh

# Installation with user (recommended)
sudo DOCKER_USER=$USER ./opt/serverbond-agent/scripts/install-docker.sh

# All features (Swarm, Buildx, Trivy)
sudo DOCKER_USER=$USER \
  ENABLE_DOCKER_SWARM=true \
  ENABLE_DOCKER_BUILDX=true \
  ENABLE_TRIVY=true \
  ./opt/serverbond-agent/scripts/install-docker.sh
```

**Docker Features:**
- ✅ Docker Engine + Compose (latest)
- ✅ Production-ready daemon configuration
- ✅ Security optimizations (seccomp, no-new-privileges)
- ✅ Automatic log rotation
- ✅ Resource limits
- ✅ Registry mirror support
- ✅ Docker Buildx (multi-platform builds)
- ✅ Docker Swarm (orchestration)
- ✅ Trivy (security scanner)
- ✅ Weekly automatic cleanup
- ✅ Monitoring scripts

**Docker for Laravel:**

```bash
cd /var/www/myproject

# Copy templates
cp /opt/serverbond-agent/templates/docker/docker-compose-laravel-simple.yml docker-compose.yml
cp /opt/serverbond-agent/templates/docker/docker-env-example .env
cp /opt/serverbond-agent/templates/docker/Dockerfile-laravel-simple Dockerfile
cp /opt/serverbond-agent/templates/docker/docker-makefile Makefile

# Start
docker compose up -d
```

For detailed information: [`templates/docker/README.md`](templates/docker/README.md)

## ☁️ Cloudflared Installation (Optional)

Securely expose your server to the internet with Cloudflare Tunnel:

```bash
# Manual installation
sudo ./opt/serverbond-agent/scripts/install-cloudflared.sh

# With automatic installation
INSTALL_CLOUDFLARED=true sudo bash install.sh
```

**Cloudflare Tunnel Features:**
- ✅ No port forwarding required
- ✅ Secure encrypted tunnel
- ✅ DDoS protection
- ✅ Automatic SSL/TLS
- ✅ Easy DNS management

**Quick Start:**

```bash
# 1. Login to Cloudflare
cloudflared-setup login

# 2. Create tunnel
cloudflared-setup create my-tunnel

# 3. Add DNS route
cloudflared-setup route my-tunnel example.com

# 4. Create config
cloudflared-setup config my-tunnel

# 5. Start service
cloudflared-setup enable

# 6. Check status
cloudflared-setup status
```

**Commands:**
```bash
cloudflared-setup help      # Help
cloudflared-setup list      # List tunnels
cloudflared-setup logs      # View logs
```

## 🛠️ Manual Script Installation

You can install services individually:

```bash
# Clone scripts
git clone https://github.com/beyazitkolemen/serverbond-agent.git
cd serverbond-agent

# Docker only
sudo ./opt/serverbond-agent/scripts/install-docker.sh

# MySQL only
sudo ./opt/serverbond-agent/scripts/install-mysql.sh

# Nginx only
sudo ./opt/serverbond-agent/scripts/install-nginx.sh

# PHP only
sudo ./opt/serverbond-agent/scripts/install-php.sh

# Redis only
sudo ./opt/serverbond-agent/scripts/install-redis.sh

# Cloudflared only
sudo ./opt/serverbond-agent/scripts/install-cloudflared.sh

# WordPress install helper
sudo ./opt/serverbond-agent/scripts/wordpress/install.sh \
  --path /var/www/example \
  --db-name example_db \
  --db-user example_user \
  --db-password secret \
  --url https://example.com \
  --title "Example" \
  --admin-user admin \
  --admin-password pass123 \
  --admin-email admin@example.com

# Update wp-config values
sudo ./opt/serverbond-agent/scripts/wordpress/update_config.sh \
  --path /var/www/example \
  --enable-debug \
  --set-raw WP_CACHE=true

# Reset WordPress permissions
sudo ./opt/serverbond-agent/scripts/wordpress/set_permissions.sh \
  --path /var/www/example
```

## 🔧 Troubleshooting

### ❌ Error: Access denied for user 'laravel'@'localhost'

If Laravel panel gives "Access denied" error:

```bash
# Automatically fix .env file
sudo /opt/serverbond-agent/scripts/fix-mysql-credentials.sh
```

This script:
- ✅ Reads MySQL password
- ✅ Backs up .env file
- ✅ Sets DB_USERNAME to root
- ✅ Adds correct password
- ✅ Clears Laravel cache
- ✅ Tests connection

### 🔍 MySQL Connection Test

For MySQL connection issues:

```bash
sudo /opt/serverbond-agent/scripts/test-mysql-connection.sh
```

### 🐳 Docker System Status

```bash
docker-monitor          # System information
docker-cleanup          # Cleanup
docker system df        # Disk usage
```

### 📋 Log Files

Installation logs:
```bash
ls -lh /tmp/serverbond-install-*.log
tail -100 /tmp/serverbond-install-*.log
```

### 🔄 Reinstallation

If installation failed:

```bash
# 1. Cleanup
sudo rm -rf /opt/serverbond-agent

# 2. Check MySQL password (save if exists)
sudo cat /opt/serverbond-agent/config/.mysql_root_password

# 3. Reinstall
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

### 🩺 Panel Health Check

```bash
# Check services
sudo systemctl status nginx
sudo systemctl status php8.4-fpm
sudo systemctl status mysql
sudo systemctl status redis-server

# Laravel logs
sudo tail -50 /var/www/html/storage/logs/laravel.log

# Nginx logs
sudo tail -50 /var/log/nginx/error.log
```

## 🔐 Sudoers Permissions

ServerBond Panel grants sudo privileges to the `www-data` user to manage system resources. All permissions are securely configured in the `/etc/sudoers.d/` directory.

### Automatically Created Sudoers Files

| File | Service | Permissions |
|------|---------|-------------|
| `serverbond-nginx` | Nginx | Service management, config editing, log reading |
| `serverbond-php` | PHP-FPM | Service management, pool config, Composer |
| `serverbond-mysql` | MySQL | Service management, database operations |
| `serverbond-redis` | Redis | Service management, redis-cli commands |
| `serverbond-supervisor` | Supervisor | Process management, config editing |
| `serverbond-certbot` | Certbot/SSL | SSL certificate management |
| `serverbond-cloudflare` | Cloudflared | Tunnel management, config editing |
| `serverbond-docker` | Docker | Container management, Docker commands |
| `serverbond-nodejs` | Node.js/PM2 | NPM, PM2 commands |
| `serverbond-python` | Python | Python3, pip3, venv management |
| `serverbond-system` | System | General system management, UFW, cron |

### Security Features

- ✅ Separate sudoers file for each service (modular structure)
- ✅ All files protected with `440` permissions
- ✅ Automatic validation with `visudo -c`
- ✅ Invalid files automatically deleted
- ✅ Principle of least privilege (only what's necessary)
- ✅ `NOPASSWD` - For panel automation

### Detailed Documentation

For detailed list of all sudoers permissions:

👉 **[SUDOERS-PERMISSIONS.md](SUDOERS-PERMISSIONS.md)**

### Manual Check

```bash
# List all sudoers files
ls -la /etc/sudoers.d/serverbond-*

# View specific file
sudo cat /etc/sudoers.d/serverbond-nginx

# Test as www-data user
sudo -u www-data sudo systemctl status nginx
```

## 📚 Documentation

- **Panel**: All site management from web interface
- **Docker**: [`templates/docker/DOCKER-README.md`](templates/docker/DOCKER-README.md)
- **Templates**: [`templates/docker/README.md`](templates/docker/README.md)
- **Sudoers**: [`SUDOERS-PERMISSIONS.md`](SUDOERS-PERMISSIONS.md)

After panel installation, you can perform all site management operations from the web interface.

## 🤝 Support

- **GitHub**: [beyazitkolemen/serverbond-agent](https://github.com/beyazitkolemen/serverbond-agent)
- **Issues**: [Report Issue](https://github.com/beyazitkolemen/serverbond-agent/issues)
- **Panel**: [serverbond-panel](https://github.com/beyazitkolemen/serverbond-panel)

## 📝 License

MIT License
