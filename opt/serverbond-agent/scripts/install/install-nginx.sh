#!/usr/bin/env bash
################################################################################
# ServerBond Agent - Nginx Installation Script
# Installs and configures Nginx web server with optional parameters
################################################################################
set -euo pipefail

# Get script directory and source lib
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

# Script information
init_script "install-nginx.sh" "Install and configure Nginx web server" "2.0.0"

# Default configuration
NGINX_SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
NGINX_SITES_ENABLED="${NGINX_SITES_ENABLED:-/etc/nginx/sites-enabled}"
NGINX_DEFAULT_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$(dirname "$SCRIPTS_DIR")/templates}"
NGINX_SCRIPT_DIR="${SCRIPTS_DIR}/nginx"

# Usage function
show_nginx_usage() {
    cat <<'USAGE'
Nginx Installation Options:
  --sites-available PATH     Sites available directory (default: /etc/nginx/sites-available)
  --sites-enabled PATH       Sites enabled directory (default: /etc/nginx/sites-enabled)
  --web-root PATH            Default web root directory (default: /var/www/html)
  --templates-dir PATH       Templates directory path
  --laravel-url URL          Laravel project URL for template selection
  --skip-firewall            Skip UFW firewall configuration
  --skip-sudoers             Skip sudoers configuration
  --skip-default-page        Skip creating default index page
  --template TYPE            Configuration template type (default|laravel|custom)
  --custom-template PATH     Path to custom template file

Environment Variables:
  NGINX_SITES_AVAILABLE      Sites available directory
  NGINX_SITES_ENABLED        Sites enabled directory  
  NGINX_DEFAULT_ROOT         Default web root directory
  TEMPLATES_DIR              Templates directory path
  LARAVEL_PROJECT_URL        Laravel project URL
  SKIP_FIREWALL              Skip firewall configuration
  SKIP_SUDOERS               Skip sudoers configuration
  SKIP_DEFAULT_PAGE          Skip default page creation
  NGINX_TEMPLATE_TYPE        Template type selection
  NGINX_CUSTOM_TEMPLATE      Custom template file path

Examples:
  # Basic installation
  ./install-nginx.sh

  # With custom web root
  ./install-nginx.sh --web-root /var/www/mysite

  # Laravel configuration
  ./install-nginx.sh --laravel-url https://myapp.com --template laravel

  # Custom template
  ./install-nginx.sh --custom-template /path/to/template.conf

  # Skip optional steps
  ./install-nginx.sh --skip-firewall --skip-sudoers
USAGE
}

# Parse arguments
parse_arguments "install-nginx.sh" "Install and configure Nginx web server" "show_nginx_usage"

# Override defaults with parameters
NGINX_SITES_AVAILABLE="$(get_param "sites-available" "$NGINX_SITES_AVAILABLE")"
NGINX_SITES_ENABLED="$(get_param "sites-enabled" "$NGINX_SITES_ENABLED")"
NGINX_DEFAULT_ROOT="$(get_param "web-root" "$NGINX_DEFAULT_ROOT")"
TEMPLATES_DIR="$(get_param "templates-dir" "$TEMPLATES_DIR")"
LARAVEL_PROJECT_URL="$(get_param "laravel-url" "${LARAVEL_PROJECT_URL:-}")"
TEMPLATE_TYPE="$(get_param "template" "${NGINX_TEMPLATE_TYPE:-default}")"
CUSTOM_TEMPLATE="$(get_param "custom-template" "${NGINX_CUSTOM_TEMPLATE:-}")"

# Check if running as root
require_root

# Validate paths
validate_path "$NGINX_SITES_AVAILABLE" || exit 1
validate_path "$NGINX_SITES_ENABLED" || exit 1

log_step "Starting Nginx installation and configuration"

# Set non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Update package lists
log_info "Updating package lists..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would run: apt-get update -qq"
else
    apt-get update -qq
fi

# Install Nginx
log_info "Installing Nginx..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would run: apt-get install -y -qq nginx"
else
    apt-get install -y -qq nginx > /dev/null
fi

# Create web root directory
log_info "Creating web root directory: $NGINX_DEFAULT_ROOT"
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would run: mkdir -p $NGINX_DEFAULT_ROOT"
else
    mkdir -p "${NGINX_DEFAULT_ROOT}"
fi

# Create sites directories
log_info "Creating sites directories..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would run: mkdir -p $NGINX_SITES_AVAILABLE $NGINX_SITES_ENABLED"
else
    mkdir -p "${NGINX_SITES_AVAILABLE}" "${NGINX_SITES_ENABLED}"
fi

# Configuration template selection
log_info "Selecting configuration template..."

if [[ -n "$CUSTOM_TEMPLATE" ]]; then
    log_info "Using custom template: $CUSTOM_TEMPLATE"
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would copy: $CUSTOM_TEMPLATE -> $NGINX_SITES_AVAILABLE/default"
    else
        if [[ -f "$CUSTOM_TEMPLATE" ]]; then
            cp "$CUSTOM_TEMPLATE" "${NGINX_SITES_AVAILABLE}/default"
        else
            log_error "Custom template file not found: $CUSTOM_TEMPLATE"
            exit 1
        fi
    fi
elif [[ "$TEMPLATE_TYPE" == "laravel" || -n "$LARAVEL_PROJECT_URL" ]]; then
    log_info "Using Laravel template..."
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would copy Laravel template"
    else
        if [[ -f "${TEMPLATES_DIR}/nginx-laravel.conf" ]]; then
            render_template "${TEMPLATES_DIR}/nginx-laravel.conf" "${NGINX_SITES_AVAILABLE}/default"
        else
            log_warning "Laravel template not found, using default configuration"
            TEMPLATE_TYPE="default"
        fi
    fi
elif [[ "$TEMPLATE_TYPE" == "default" ]]; then
    log_info "Using default template..."
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would copy default template"
    else
        if [[ -f "${TEMPLATES_DIR}/nginx-default.conf" ]]; then
            render_template "${TEMPLATES_DIR}/nginx-default.conf" "${NGINX_SITES_AVAILABLE}/default"
        else
            log_warning "Default template not found, creating basic configuration"
            TEMPLATE_TYPE="basic"
        fi
    fi
fi

# Create basic configuration if no template was used
if [[ "$TEMPLATE_TYPE" == "basic" ]]; then
    log_info "Creating basic Nginx configuration..."
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would create basic configuration"
    else
        cat > "${NGINX_SITES_AVAILABLE}/default" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root ${NGINX_DEFAULT_ROOT};
    index index.html index.htm index.php;
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
    fi
fi

# Create default index page
if ! has_flag "skip-default-page" && [[ -z "$LARAVEL_PROJECT_URL" ]]; then
    log_info "Creating default index page..."
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would create default index.html"
    else
        cat > "${NGINX_DEFAULT_ROOT}/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ServerBond Agent</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            text-align: center; 
            padding: 60px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        h1 { 
            color: #fff; 
            font-size: 2.5em;
            margin-bottom: 20px;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }
        p {
            font-size: 1.2em;
            margin-bottom: 30px;
            opacity: 0.9;
        }
        .status {
            display: inline-block;
            background: rgba(76, 175, 80, 0.8);
            padding: 10px 20px;
            border-radius: 25px;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 ServerBond Agent</h1>
        <p>Nginx is running successfully!</p>
        <div class="status">✅ Online</div>
    </div>
</body>
</html>
EOF
    fi
elif [[ -n "$LARAVEL_PROJECT_URL" ]]; then
    log_info "Laravel project detected, skipping default page creation"
fi

# Set permissions
log_info "Setting proper permissions..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would set permissions for: $NGINX_DEFAULT_ROOT"
else
    chown -R www-data:www-data "${NGINX_DEFAULT_ROOT}"
    chmod -R 755 "${NGINX_DEFAULT_ROOT}"
fi

# Enable and start Nginx service
log_info "Enabling and starting Nginx service..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would enable and start Nginx service"
else
    systemctl_safe enable nginx
    systemctl_safe restart nginx
fi

# Configure firewall
if ! has_flag "skip-firewall" && check_command ufw; then
    log_info "Configuring UFW firewall rules..."
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would run: ufw allow 'Nginx Full'"
    else
        ufw allow 'Nginx Full' > /dev/null 2>&1 || log_warning "Failed to configure UFW rules"
    fi
fi

# Configure sudoers
if ! has_flag "skip-sudoers"; then
    log_info "Configuring sudoers permissions..."
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would configure sudoers for nginx scripts"
    else
        if ! create_script_sudoers "nginx" "${NGINX_SCRIPT_DIR}"; then
            log_error "Failed to configure sudoers permissions"
            exit 1
        fi
    fi
fi

# Validate installation
log_info "Validating Nginx installation..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would validate Nginx installation"
else
    if systemctl is-active --quiet nginx; then
        log_success "Nginx successfully installed and running"
        log_info "Web root: $NGINX_DEFAULT_ROOT"
        log_info "Sites available: $NGINX_SITES_AVAILABLE"
        log_info "Sites enabled: $NGINX_SITES_ENABLED"
    else
        log_error "Failed to start Nginx service!"
        log_error "Service status:"
        systemctl status nginx --no-pager || true
        log_error "Recent logs:"
        journalctl -u nginx --no-pager | tail -n 10 || true
        exit 1
    fi
fi

# Test configuration
log_info "Testing Nginx configuration..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would test Nginx configuration"
else
    if nginx -t; then
        log_success "Nginx configuration is valid"
    else
        log_error "Nginx configuration test failed!"
        exit 1
    fi
fi

finish_script 0 "Nginx installation completed successfully"