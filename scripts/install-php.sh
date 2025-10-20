#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
PHP_VERSION="${PHP_VERSION:-8.4}"
PHP_FPM_SOCKET="${PHP_FPM_SOCKET:-/var/run/php/php${PHP_VERSION}-fpm.sock}"
PHP_FPM_POOL="${PHP_FPM_POOL:-/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf}"
PHP_INI="${PHP_INI:-/etc/php/${PHP_VERSION}/fpm/php.ini}"
PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-256M}"
PHP_UPLOAD_MAX="${PHP_UPLOAD_MAX:-100M}"
PHP_MAX_EXECUTION="${PHP_MAX_EXECUTION:-300}"

log_info "PHP ${PHP_VERSION} kuruluyor..."

export DEBIAN_FRONTEND=noninteractive

# Add PPA
add-apt-repository -y ppa:ondrej/php 2>&1 | grep -v "^$" || true
apt-get update -qq 2>&1 | grep -v "^$" || true

# Install PHP packages
apt-get install -y -qq \
    php${PHP_VERSION}-{fpm,cli,common,mysql,pgsql,sqlite3,redis} \
    php${PHP_VERSION}-{mbstring,xml,curl,zip,gd,bcmath,intl,soap,imagick,readline} \
    2>&1 | grep -v "^$" || true

# FPM Pool configuration
cat > "${PHP_FPM_POOL}" << EOF
[www]
user = www-data
group = www-data
listen = ${PHP_FPM_SOCKET}
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
EOF

# PHP.ini optimizations
sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" "${PHP_INI}"
sed -i "s/upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX}/" "${PHP_INI}"
sed -i "s/post_max_size = .*/post_max_size = ${PHP_UPLOAD_MAX}/" "${PHP_INI}"
sed -i "s/max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION}/" "${PHP_INI}"
sed -i 's/;opcache.enable=.*/opcache.enable=1/' "${PHP_INI}"
sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=256/' "${PHP_INI}"
sed -i 's/;date.timezone =.*/date.timezone = Europe\/Istanbul/' "${PHP_INI}"

systemctl_safe enable "php${PHP_VERSION}-fpm"
systemctl_safe restart "php${PHP_VERSION}-fpm"

# Install Composer
log_info "Composer kuruluyor..."
EXPECTED_SIG="$(curl -sS https://composer.github.io/installer.sig 2>/dev/null)"
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php 2>/dev/null
ACTUAL_SIG="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');" 2>/dev/null)"

if [ "$EXPECTED_SIG" = "$ACTUAL_SIG" ]; then
    php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
    rm /tmp/composer-setup.php
    log_success "Composer kuruldu"
fi

log_success "PHP ${PHP_VERSION} kuruldu"
