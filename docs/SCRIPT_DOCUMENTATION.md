# ServerBond Agent Scripts Documentation

## Overview

The ServerBond Agent scripts provide a comprehensive set of tools for managing web servers, applications, and system services. All scripts follow a professional structure with enhanced parameter handling, error management, and logging.

## Script Architecture

### Directory Structure

```
/opt/serverbond-agent/scripts/
├── lib.sh                    # Common functions and utilities
├── install/                  # One-time installation scripts
│   ├── install-nginx.sh
│   ├── install-php.sh
│   ├── install-mysql.sh
│   ├── install-redis.sh
│   ├── install-docker.sh
│   ├── install-nodejs.sh
│   ├── install-python.sh
│   ├── install-supervisor.sh
│   ├── install-certbot.sh
│   ├── install-cloudflared.sh
│   └── install-serverbond-panel.sh
├── nginx/                    # Nginx management scripts
├── mysql/                    # MySQL management scripts
├── php/                      # PHP management scripts
├── redis/                    # Redis management scripts
├── docker/                   # Docker management scripts
├── ssl/                      # SSL/TLS management scripts
├── supervisor/               # Supervisor process management
├── system/                   # System management scripts
├── user/                     # User management scripts
├── maintenance/              # Maintenance and backup scripts
├── deploy/                   # Deployment scripts
├── node/                     # Node.js management scripts
├── python/                   # Python management scripts
├── cloudflared/              # Cloudflare Tunnel scripts
├── wordpress/                # WordPress management scripts
└── meta/                     # Meta and diagnostic scripts
```

### Common Features

All scripts include:
- **Parameter parsing** with `--help` support
- **Dry-run mode** (`--dry-run` or `-n`)
- **Debug mode** (`--debug` or `-d`)
- **Quiet mode** (`--quiet` or `-q`)
- **Version information** (`--version` or `-v`)
- **Comprehensive error handling**
- **Professional logging**
- **Input validation**

## Installation Scripts

### Nginx Installation (`install/install-nginx.sh`)

Installs and configures Nginx web server.

**Parameters:**
- `--sites-available PATH` - Sites available directory (default: /etc/nginx/sites-available)
- `--sites-enabled PATH` - Sites enabled directory (default: /etc/nginx/sites-enabled)
- `--web-root PATH` - Default web root directory (default: /var/www/html)
- `--templates-dir PATH` - Templates directory path
- `--laravel-url URL` - Laravel project URL for template selection
- `--skip-firewall` - Skip UFW firewall configuration
- `--skip-sudoers` - Skip sudoers configuration
- `--skip-default-page` - Skip creating default index page
- `--template TYPE` - Configuration template type (default|laravel|custom)
- `--custom-template PATH` - Path to custom template file

**Examples:**
```bash
# Basic installation
./install-nginx.sh

# With custom web root
./install-nginx.sh --web-root /var/www/mysite

# Laravel configuration
./install-nginx.sh --laravel-url https://myapp.com --template laravel

# Dry run
./install-nginx.sh --dry-run
```

### PHP Installation (`install/install-php.sh`)

Installs PHP with specified version and extensions.

**Parameters:**
- `--version VERSION` - PHP version (default: 8.3)
- `--memory-limit SIZE` - Memory limit (default: 256M)
- `--upload-max SIZE` - Upload max filesize (default: 100M)
- `--max-execution TIME` - Max execution time (default: 300)
- `--timezone ZONE` - Timezone (default: Europe/London)
- `--extensions LIST` - Comma-separated list of extensions
- `--skip-composer` - Skip Composer installation
- `--skip-fpm` - Skip PHP-FPM configuration

**Examples:**
```bash
# Install PHP 8.3
./install-php.sh --version 8.3

# With custom settings
./install-php.sh --version 8.2 --memory-limit 512M --upload-max 200M

# With specific extensions
./install-php.sh --extensions "redis,imagick,gd"
```

### MySQL Installation (`install/install-mysql.sh`)

Installs and configures MySQL database server.

**Parameters:**
- `--root-password PASSWORD` - Root password
- `--data-dir PATH` - Data directory (default: /var/lib/mysql)
- `--port PORT` - Port number (default: 3306)
- `--skip-secure-installation` - Skip secure installation
- `--skip-sudoers` - Skip sudoers configuration

**Examples:**
```bash
# Basic installation
./install-mysql.sh

# With custom password
./install-mysql.sh --root-password mypassword

# Custom configuration
./install-mysql.sh --data-dir /data/mysql --port 3307
```

## Management Scripts

### Nginx Site Management

#### Add Site (`nginx/add_site.sh`)

Creates a new Nginx site configuration.

**Parameters:**
- `--domain DOMAIN` - Site domain name (required)
- `--root PATH` - Web root directory (default: /var/www/{domain})
- `--template PATH` - Custom template file path
- `--template-type TYPE` - Template type (default|laravel|php|static)
- `--php-socket SOCKET` - PHP-FPM socket path
- `--enable-ssl` - Enable SSL configuration
- `--ssl-email EMAIL` - Email for SSL certificate
- `--force` - Overwrite existing configuration

**Examples:**
```bash
# Basic site
./nginx/add_site.sh --domain example.com

# Laravel site
./nginx/add_site.sh --domain myapp.com --template-type laravel

# With SSL
./nginx/add_site.sh --domain example.com --enable-ssl --ssl-email admin@example.com
```

#### List Sites (`nginx/list_sites.sh`)

Lists all configured Nginx sites.

**Parameters:**
- `--format FORMAT` - Output format (table|list|json)
- `--show-disabled` - Include disabled sites
- `--show-ssl` - Show SSL status

**Examples:**
```bash
# List all sites
./nginx/list_sites.sh

# JSON format
./nginx/list_sites.sh --format json

# Include disabled sites
./nginx/list_sites.sh --show-disabled
```

#### Remove Site (`nginx/remove_site.sh`)

Removes a Nginx site configuration.

**Parameters:**
- `--domain DOMAIN` - Site domain name (required)
- `--purge-root` - Remove web root directory
- `--force` - Skip confirmation

**Examples:**
```bash
# Remove site
./nginx/remove_site.sh --domain example.com

# Remove with web root
./nginx/remove_site.sh --domain example.com --purge-root
```

### MySQL Database Management

#### Create Database (`mysql/create_database.sh`)

Creates a new MySQL database.

**Parameters:**
- `--name NAME` - Database name (required)
- `--charset CHARSET` - Character set (default: utf8mb4)
- `--collation COLLATION` - Collation (default: utf8mb4_unicode_ci)
- `--user USER` - Database user
- `--password PASSWORD` - User password

**Examples:**
```bash
# Create database
./mysql/create_database.sh --name myapp_db

# With custom charset
./mysql/create_database.sh --name myapp_db --charset utf8mb4 --collation utf8mb4_unicode_ci
```

#### Create User (`mysql/create_user.sh`)

Creates a new MySQL user.

**Parameters:**
- `--user USER` - Username (required)
- `--password PASSWORD` - Password (required)
- `--host HOST` - Host (default: %)
- `--database DATABASE` - Grant access to database
- `--privileges PRIVILEGES` - Privileges (default: ALL)

**Examples:**
```bash
# Create user
./mysql/create_user.sh --user myuser --password mypass

# With database access
./mysql/create_user.sh --user myuser --password mypass --database myapp_db
```

### PHP Management

#### Install Extension (`php/install_extension.sh`)

Installs a PHP extension.

**Parameters:**
- `--extension NAME` - Extension name (required)
- `--version VERSION` - PHP version (default: current)
- `--force` - Force installation

**Examples:**
```bash
# Install extension
./php/install_extension.sh --extension redis

# For specific PHP version
./php/install_extension.sh --extension imagick --version 8.2
```

#### Change Version (`php/change_version.sh`)

Changes the active PHP version.

**Parameters:**
- `--version VERSION` - PHP version (required)
- `--update-alternatives` - Update alternatives
- `--restart-services` - Restart related services

**Examples:**
```bash
# Change to PHP 8.2
./php/change_version.sh --version 8.2

# With service restart
./php/change_version.sh --version 8.3 --restart-services
```

### Docker Management

#### Compose Up (`docker/compose_up.sh`)

Starts Docker Compose services.

**Parameters:**
- `--path PATH` - Project directory (default: .)
- `--file FILE` - Compose file (default: docker-compose.yml)
- `--no-detach` - Run in foreground
- `--build` - Build images before starting

**Examples:**
```bash
# Start services
./docker/compose_up.sh

# With custom path
./docker/compose_up.sh --path /var/www/myapp

# Build and start
./docker/compose_up.sh --build
```

#### Build Image (`docker/build_image.sh`)

Builds a Docker image.

**Parameters:**
- `--tag TAG` - Image tag (required)
- `--path PATH` - Build context (default: .)
- `--file FILE` - Dockerfile (default: Dockerfile)
- `--no-cache` - Build without cache
- `--push` - Push to registry after build

**Examples:**
```bash
# Build image
./docker/build_image.sh --tag myapp:latest

# With custom Dockerfile
./docker/build_image.sh --tag myapp:latest --file Dockerfile.prod
```

### SSL Management

#### Create SSL (`ssl/create_ssl.sh`)

Creates SSL certificate using Let's Encrypt.

**Parameters:**
- `--domain DOMAIN` - Domain name (required)
- `--email EMAIL` - Email address (required)
- `--webroot PATH` - Web root directory
- `--staging` - Use staging environment
- `--force` - Force renewal

**Examples:**
```bash
# Create SSL certificate
./ssl/create_ssl.sh --domain example.com --email admin@example.com

# Staging environment
./ssl/create_ssl.sh --domain example.com --email admin@example.com --staging
```

## Deployment Scripts

### Deploy Project (`deploy/deploy_project.sh`)

Deploys a project from Git repository.

**Parameters:**
- `--repo URL` - Git repository URL (required)
- `--branch BRANCH` - Branch name (default: main)
- `--path PATH` - Deployment path (default: /var/www)
- `--keep RELEASES` - Number of releases to keep (default: 5)
- `--skip-composer` - Skip Composer install
- `--skip-npm` - Skip NPM build
- `--skip-migrate` - Skip database migrations

**Examples:**
```bash
# Deploy project
./deploy/deploy_project.sh --repo https://github.com/user/repo.git

# With custom settings
./deploy/deploy_project.sh --repo https://github.com/user/repo.git --branch develop --keep 3
```

## Maintenance Scripts

### Backup Database (`maintenance/backup_db.sh`)

Creates database backup.

**Parameters:**
- `--database NAME` - Database name (required)
- `--output PATH` - Output file path
- `--compress` - Compress backup
- `--encrypt` - Encrypt backup

**Examples:**
```bash
# Backup database
./maintenance/backup_db.sh --database myapp_db

# With compression
./maintenance/backup_db.sh --database myapp_db --compress
```

### Backup Files (`maintenance/backup_files.sh`)

Creates file system backup.

**Parameters:**
- `--source PATH` - Source directory (required)
- `--destination PATH` - Destination directory (required)
- `--exclude PATTERNS` - Exclude patterns
- `--compress` - Compress backup

**Examples:**
```bash
# Backup files
./maintenance/backup_files.sh --source /var/www --destination /backups

# With exclusions
./maintenance/backup_files.sh --source /var/www --destination /backups --exclude "*.log,*.tmp"
```

## System Scripts

### System Status (`system/status.sh`)

Shows system status information.

**Parameters:**
- `--format FORMAT` - Output format (table|json)
- `--services` - Show service status
- `--resources` - Show resource usage

**Examples:**
```bash
# Show system status
./system/status.sh

# JSON format
./system/status.sh --format json
```

### Update OS (`system/update_os.sh`)

Updates the operating system.

**Parameters:**
- `--upgrade` - Perform full upgrade
- `--security-only` - Security updates only
- `--reboot` - Reboot after update

**Examples:**
```bash
# Update system
./system/update_os.sh

# Full upgrade with reboot
./system/update_os.sh --upgrade --reboot
```

## WordPress Scripts

### Install WordPress (`wordpress/install.sh`)

Installs WordPress.

**Parameters:**
- `--path PATH` - Installation path (required)
- `--db-name NAME` - Database name (required)
- `--db-user USER` - Database user (required)
- `--db-password PASS` - Database password (required)
- `--url URL` - Site URL
- `--title TITLE` - Site title
- `--admin-user USER` - Admin username
- `--admin-password PASS` - Admin password
- `--admin-email EMAIL` - Admin email

**Examples:**
```bash
# Install WordPress
./wordpress/install.sh --path /var/www/wordpress --db-name wp_db --db-user wp_user --db-password wp_pass

# Complete installation
./wordpress/install.sh --path /var/www/wordpress --db-name wp_db --db-user wp_user --db-password wp_pass --url https://example.com --title "My Site" --admin-user admin --admin-password admin123 --admin-email admin@example.com
```

## Common Usage Patterns

### Dry Run Mode

All scripts support dry-run mode to preview actions:

```bash
# Preview what would be done
./nginx/add_site.sh --domain example.com --dry-run
```

### Debug Mode

Enable debug mode for detailed output:

```bash
# Show debug information
./install-nginx.sh --debug
```

### Quiet Mode

Suppress non-error output:

```bash
# Quiet operation
./mysql/create_database.sh --name mydb --quiet
```

### Environment Variables

Many scripts can be configured using environment variables:

```bash
# Set environment variables
export NGINX_DEFAULT_ROOT="/var/www/html"
export PHP_VERSION="8.3"
export MYSQL_ROOT_PASSWORD="mypassword"

# Run script
./install-nginx.sh
```

## Error Handling

All scripts include comprehensive error handling:

- **Exit codes**: 0 for success, non-zero for errors
- **Error logging**: Detailed error messages
- **Validation**: Input parameter validation
- **Rollback**: Automatic cleanup on failure
- **Logging**: Structured logging with timestamps

## Security Features

- **Root requirement**: Most scripts require root privileges
- **Input validation**: All inputs are validated
- **Path sanitization**: Paths are sanitized and validated
- **Sudoers management**: Automatic sudoers configuration
- **Permission management**: Proper file permissions

## Best Practices

1. **Always use dry-run mode first** for destructive operations
2. **Check script help** with `--help` before running
3. **Use environment variables** for configuration
4. **Monitor logs** for error messages
5. **Test in staging** before production use
6. **Keep backups** before major changes
7. **Use version control** for custom configurations

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure running as root
2. **Service not found**: Check if service is installed
3. **Configuration errors**: Validate configuration files
4. **Port conflicts**: Check if ports are available
5. **Disk space**: Ensure sufficient disk space

### Debug Steps

1. Enable debug mode: `--debug`
2. Check logs: `/var/log/serverbond/`
3. Validate configuration: Use dry-run mode
4. Check service status: `systemctl status <service>`
5. Review error messages: Check stderr output

## Support

For issues and questions:
- Check script help: `./script.sh --help`
- Enable debug mode: `./script.sh --debug`
- Review logs: `/var/log/serverbond/`
- Report issues: GitHub Issues