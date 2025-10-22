#!/usr/bin/env bash
################################################################################
# ServerBond Agent - Add Nginx Site
# Creates and configures a new Nginx site with optional parameters
################################################################################
set -euo pipefail

# Get script directory and source lib
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
source "${SCRIPTS_DIR}/lib.sh"

# Script information
init_script "add_site.sh" "Add new Nginx site configuration" "2.0.0"

# Default configuration
SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
SITES_ENABLED="${NGINX_SITES_ENABLED:-/etc/nginx/sites-enabled}"
DEFAULT_ROOT_BASE="${NGINX_DEFAULT_ROOT:-/var/www}"
PHP_FPM_SOCKET="${PHP_FPM_SOCKET:-unix:/run/php/php-fpm.sock}"

# Usage function
show_add_site_usage() {
    cat <<'USAGE'
Add Nginx Site Options:
  --domain DOMAIN            Site domain name (required)
  --root PATH                Web root directory (default: /var/www/{domain})
  --template PATH            Custom template file path
  --template-type TYPE       Template type (default|laravel|php|static)
  --php-socket SOCKET        PHP-FPM socket path (default: unix:/run/php/php-fpm.sock)
  --enable-ssl               Enable SSL configuration
  --ssl-email EMAIL          Email for SSL certificate
  --force                    Overwrite existing configuration
  --no-reload                Skip Nginx reload after configuration

Environment Variables:
  NGINX_SITES_AVAILABLE      Sites available directory
  NGINX_SITES_ENABLED        Sites enabled directory
  NGINX_DEFAULT_ROOT         Default web root base directory
  PHP_FPM_SOCKET             PHP-FPM socket path

Examples:
  # Basic site
  ./add_site.sh --domain example.com

  # With custom web root
  ./add_site.sh --domain example.com --root /var/www/custom

  # Laravel site
  ./add_site.sh --domain myapp.com --template-type laravel

  # With SSL
  ./add_site.sh --domain example.com --enable-ssl --ssl-email admin@example.com

  # Using custom template
  ./add_site.sh --domain example.com --template /path/to/template.conf
USAGE
}

# Parse arguments
parse_arguments "add_site.sh" "Add new Nginx site configuration" "show_add_site_usage"

# Get parameters
DOMAIN="$(get_param "domain")"
WEB_ROOT="$(get_param "root" "${DEFAULT_ROOT_BASE}/${DOMAIN}")"
TEMPLATE="$(get_param "template")"
TEMPLATE_TYPE="$(get_param "template-type" "default")"
PHP_FPM_SOCKET="$(get_param "php-socket" "$PHP_FPM_SOCKET")"
SSL_EMAIL="$(get_param "ssl-email")"

# Validate required parameters
if [[ -z "$DOMAIN" ]]; then
    log_error "Domain name (--domain) is required"
    show_help "add_site.sh" "Add new Nginx site configuration" "show_add_site_usage"
    exit 1
fi

# Validate domain format
if ! validate_domain "$DOMAIN"; then
    exit 1
fi

# Validate email if SSL is enabled
if has_flag "enable-ssl" && [[ -n "$SSL_EMAIL" ]] && ! validate_email "$SSL_EMAIL"; then
    exit 1
fi

# Check if running as root
require_root

# Validate paths
validate_path "$SITES_AVAILABLE" || exit 1
validate_path "$SITES_ENABLED" || exit 1

log_step "Adding Nginx site: $DOMAIN"

# Set up file paths
CONFIG_FILE="${SITES_AVAILABLE}/${DOMAIN}.conf"
ENABLED_LINK="${SITES_ENABLED}/${DOMAIN}.conf"

# Check if site already exists
if [[ -f "$CONFIG_FILE" ]] && ! has_flag "force"; then
    log_error "Site configuration already exists: $CONFIG_FILE"
    log_error "Use --force to overwrite existing configuration"
    exit 1
fi

# Create web root directory
log_info "Creating web root directory: $WEB_ROOT"
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would create directory: $WEB_ROOT"
else
    mkdir -p "${WEB_ROOT}"
    chown -R www-data:www-data "${WEB_ROOT}"
    chmod -R 755 "${WEB_ROOT}"
fi

# Template processing function
render_template() {
    local src="$1"
    local dest="$2"
    
    if check_command envsubst; then
        SERVER_NAME="${DOMAIN}" DOCUMENT_ROOT="${WEB_ROOT}" PHP_FPM_SOCKET="${PHP_FPM_SOCKET}" \
        envsubst '$SERVER_NAME $DOCUMENT_ROOT $PHP_FPM_SOCKET' < "$src" > "$dest"
    elif check_command python3; then
        python3 - "$src" "$dest" "$DOMAIN" "$WEB_ROOT" "$PHP_FPM_SOCKET" <<'PY'
import sys, pathlib
src, dest, server_name, document_root, php_socket = sys.argv[1:6]
content = pathlib.Path(src).read_text(encoding='utf-8')
replacements = {
    '$SERVER_NAME': server_name,
    '${SERVER_NAME}': server_name,
    '{{SERVER_NAME}}': server_name,
    '$DOCUMENT_ROOT': document_root,
    '${DOCUMENT_ROOT}': document_root,
    '{{DOCUMENT_ROOT}}': document_root,
    '$PHP_FPM_SOCKET': php_socket,
    '${PHP_FPM_SOCKET}': php_socket,
    '{{PHP_FPM_SOCKET}}': php_socket,
}
for needle, value in replacements.items():
    content = content.replace(needle, value)
pathlib.Path(dest).write_text(content, encoding='utf-8')
PY
    else
        log_error "Neither envsubst nor python3 found. Cannot process template."
        exit 1
    fi
}

# Create configuration file
log_info "Creating Nginx configuration..."

if [[ -n "$TEMPLATE" ]]; then
    # Custom template
    if [[ -f "$TEMPLATE" ]]; then
        log_info "Using custom template: $TEMPLATE"
        if has_flag "dry-run" || has_flag "n"; then
            log_info "[DRY RUN] Would render template: $TEMPLATE -> $CONFIG_FILE"
        else
            render_template "$TEMPLATE" "$CONFIG_FILE"
        fi
    elif [[ -f "${ROOT_DIR}/templates/${TEMPLATE}" ]]; then
        log_info "Using template from templates directory: ${ROOT_DIR}/templates/${TEMPLATE}"
        if has_flag "dry-run" || has_flag "n"; then
            log_info "[DRY RUN] Would render template: ${ROOT_DIR}/templates/${TEMPLATE} -> $CONFIG_FILE"
        else
            render_template "${ROOT_DIR}/templates/${TEMPLATE}" "$CONFIG_FILE"
        fi
    else
        log_error "Template file not found: $TEMPLATE"
        exit 1
    fi
else
    # Generate configuration based on template type
    log_info "Generating configuration for template type: $TEMPLATE_TYPE"
    
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would generate $TEMPLATE_TYPE configuration"
    else
        case "$TEMPLATE_TYPE" in
            "laravel")
                cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${WEB_ROOT}/public;
    index index.php index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass ${PHP_FPM_SOCKET};
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
                ;;
            "php")
                cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${WEB_ROOT};
    index index.php index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass ${PHP_FPM_SOCKET};
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
                ;;
            "static")
                cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${WEB_ROOT};
    index index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
                ;;
            *)
                # Default configuration
                cat > "$CONFIG_FILE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${WEB_ROOT};
    index index.php index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass ${PHP_FPM_SOCKET};
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
                ;;
        esac
    fi
fi

# Enable site
log_info "Enabling site..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would create symlink: $CONFIG_FILE -> $ENABLED_LINK"
else
    ln -sf "$CONFIG_FILE" "$ENABLED_LINK"
fi

# Test Nginx configuration
log_info "Testing Nginx configuration..."
if has_flag "dry-run" || has_flag "n"; then
    log_info "[DRY RUN] Would test Nginx configuration"
else
    if nginx -t; then
        log_success "Nginx configuration is valid"
    else
        log_error "Nginx configuration test failed!"
        log_error "Removing enabled site link"
        rm -f "$ENABLED_LINK"
        exit 1
    fi
fi

# Reload Nginx
if ! has_flag "no-reload"; then
    log_info "Reloading Nginx..."
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would reload Nginx"
    else
        systemctl_safe reload nginx
    fi
fi

# Enable SSL if requested
if has_flag "enable-ssl"; then
    log_info "SSL configuration requested..."
    if has_flag "dry-run" || has_flag "n"; then
        log_info "[DRY RUN] Would enable SSL for $DOMAIN"
    else
        if [[ -n "$SSL_EMAIL" ]]; then
            # Use the SSL script if available
            if [[ -f "${SCRIPTS_DIR}/ssl/enable_ssl.sh" ]]; then
                log_info "Enabling SSL certificate..."
                "${SCRIPTS_DIR}/ssl/enable_ssl.sh" --domain "$DOMAIN" --email "$SSL_EMAIL"
            else
                log_warning "SSL script not found, manual SSL configuration required"
            fi
        else
            log_warning "SSL email not provided, skipping SSL configuration"
        fi
    fi
fi

# Final validation
if ! has_flag "dry-run" && ! has_flag "n"; then
    if systemctl is-active --quiet nginx; then
        log_success "Site '$DOMAIN' successfully added and enabled"
        log_info "Configuration file: $CONFIG_FILE"
        log_info "Web root: $WEB_ROOT"
        log_info "Access URL: http://$DOMAIN"
    else
        log_error "Nginx service is not running!"
        exit 1
    fi
else
    log_success "[DRY RUN] Site '$DOMAIN' would be successfully added"
fi

finish_script 0 "Site addition completed successfully"