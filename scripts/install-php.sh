#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# --- Varsayılanlar ---
PHP_VERSION="${PHP_VERSION:-8.3}"
PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-256M}"
PHP_UPLOAD_MAX="${PHP_UPLOAD_MAX:-100M}"
PHP_MAX_EXECUTION="${PHP_MAX_EXECUTION:-300}"
PHP_TIMEZONE="${PHP_TIMEZONE:-Europe/Istanbul}"
PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"

log_info "=== PHP ${PHP_VERSION} kurulumu başlıyor ==="
export DEBIAN_FRONTEND=noninteractive

# --- PPA ekle (ondrej/php) ---
if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    log_info "PHP PPA ekleniyor..."
    add-apt-repository -y ppa:ondrej/php > /dev/null
    apt-get update -qq
fi

# --- Paket kurulumu ---
log_info "PHP ve gerekli eklentiler yükleniyor..."
apt-get install -y -qq \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-{mysql,pgsql,sqlite3,redis,mbstring,xml,curl,zip,gd,bcmath,intl,soap,imagick,readline,opcache} \
    > /dev/null

# --- FPM Pool yapılandırması ---
FPM_POOL_FILE="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
log_info "FPM pool yapılandırması güncelleniyor..."
sed -i 's/^user = .*/user = www-data/' "$FPM_POOL_FILE"
sed -i 's/^group = .*/group = www-data/' "$FPM_POOL_FILE"
sed -i "s|^listen = .*|listen = /run/php/php${PHP_VERSION}-fpm.sock|" "$FPM_POOL_FILE"
sed -i 's/^;listen.owner =.*/listen.owner = www-data/' "$FPM_POOL_FILE"
sed -i 's/^;listen.group =.*/listen.group = www-data/' "$FPM_POOL_FILE"
sed -i 's/^;listen.mode =.*/listen.mode = 0660/' "$FPM_POOL_FILE"

# --- php.ini optimizasyonları ---
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
log_info "PHP ini optimizasyonları uygulanıyor..."
sed -i "s/^memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" "$PHP_INI"
sed -i "s/^upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX}/" "$PHP_INI"
sed -i "s/^post_max_size = .*/post_max_size = ${PHP_UPLOAD_MAX}/" "$PHP_INI"
sed -i "s/^max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION}/" "$PHP_INI"
sed -i "s|^;date.timezone =.*|date.timezone = ${PHP_TIMEZONE}|" "$PHP_INI"

# OPcache etkinleştir
grep -q '^opcache.enable=1' "$PHP_INI" || cat >> "$PHP_INI" <<'EOF'

; === Performance optimizations ===
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=10000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
EOF

# --- Servis yönetimi ---
log_info "PHP-FPM servisi yeniden başlatılıyor..."
systemctl_safe enable "$PHP_FPM_SERVICE"
systemctl_safe restart "$PHP_FPM_SERVICE"

if ! systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
    log_error "PHP-FPM başlatılamadı!"
    journalctl -u "$PHP_FPM_SERVICE" --no-pager | tail -n 10
    exit 1
fi

# --- Composer kurulumu ---
if ! command -v composer >/dev/null 2>&1; then
    log_info "Composer kurulumu başlatılıyor..."
    EXPECTED_SIG="$(curl -fsSL https://composer.github.io/installer.sig)"
    curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
    ACTUAL_SIG="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"

    if [[ "$EXPECTED_SIG" == "$ACTUAL_SIG" ]]; then
        php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
        rm /tmp/composer-setup.php
        log_success "Composer başarıyla kuruldu"
    else
        log_warn "Composer imza doğrulaması başarısız, kurulmadı."
        rm -f /tmp/composer-setup.php
    fi
else
    log_info "Composer zaten kurulu"
fi

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

# www-data kullanıcısı için PHP-FPM yetkileri
cat > /etc/sudoers.d/serverbond-php <<EOF
# ServerBond Panel - PHP-FPM Yönetimi
# www-data kullanıcısının PHP-FPM işlemlerini yapabilmesi için gerekli izinler

# PHP-FPM servisi yönetimi (dinamik versiyon desteği)
www-data ALL=(ALL) NOPASSWD: /bin/systemctl start php*-fpm
www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop php*-fpm
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart php*-fpm
www-data ALL=(ALL) NOPASSWD: /bin/systemctl reload php*-fpm
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status php*-fpm
www-data ALL=(ALL) NOPASSWD: /bin/systemctl enable php*-fpm
www-data ALL=(ALL) NOPASSWD: /bin/systemctl disable php*-fpm

# PHP ini dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/php/*/fpm/php.ini
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/php/*/cli/php.ini
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/php/*/fpm/pool.d/*

# PHP-FPM pool yapılandırma dosyaları
www-data ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/php/*/fpm/pool.d/*
www-data ALL=(ALL) NOPASSWD: /bin/cp * /etc/php/*/fpm/pool.d/*
www-data ALL=(ALL) NOPASSWD: /bin/mv * /etc/php/*/fpm/pool.d/*
www-data ALL=(ALL) NOPASSWD: /bin/rm /etc/php/*/fpm/pool.d/*.conf

# PHP log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /var/log/php*-fpm.log
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /var/log/php*-fpm.log
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /var/log/php*-fpm.log

# Composer global olarak çalıştırma
www-data ALL=(ALL) NOPASSWD: /usr/local/bin/composer *
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-php

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-php >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-php
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"

# --- Son durum ---
log_success "PHP ${PHP_VERSION} kurulumu tamamlandı!"
log_info "PHP-FPM socket: /run/php/php${PHP_VERSION}-fpm.sock"
log_info "php.ini konumu: ${PHP_INI}"
log_info "Composer sürümü: $(composer --version 2>/dev/null || echo 'Kurulu değil')"
