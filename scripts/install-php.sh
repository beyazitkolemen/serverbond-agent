#!/bin/bash

#############################################
# PHP Multi-Version Kurulum Scripti
# PHP 8.1, 8.2, 8.3 versiyonlarını kurar
#############################################

set -e

# Script dizinini bul
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Common fonksiyonları yükle
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
elif [ -f "/opt/serverbond-agent/scripts/common.sh" ]; then
    source /opt/serverbond-agent/scripts/common.sh
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
fi

# PHP versiyonları
PHP_VERSIONS=("8.1" "8.2" "8.3")
DEFAULT_VERSION="8.2"

log_info "PHP kurulumu başlıyor..."

# Ondrej PPA ekle
log_info "Ondrej PPA repository ekleniyor..."
apt-get install -y -qq software-properties-common
add-apt-repository -y ppa:ondrej/php
apt-get update -qq

# Her PHP versiyonu için kurulum
for VERSION in "${PHP_VERSIONS[@]}"; do
    log_info "PHP $VERSION kuruluyor..."
    
    # Ana paketler
    apt-get install -y -qq \
        php${VERSION}-fpm \
        php${VERSION}-cli \
        php${VERSION}-common \
        php${VERSION}-mysql \
        php${VERSION}-pgsql \
        php${VERSION}-sqlite3 \
        php${VERSION}-redis \
        php${VERSION}-mbstring \
        php${VERSION}-xml \
        php${VERSION}-curl \
        php${VERSION}-zip \
        php${VERSION}-gd \
        php${VERSION}-bcmath \
        php${VERSION}-intl \
        php${VERSION}-soap \
        php${VERSION}-imagick \
        php${VERSION}-readline
    
    # PHP-FPM servisini başlat ve etkinleştir
    systemctl_safe enable php${VERSION}-fpm
    systemctl_safe start php${VERSION}-fpm
    
    # Servis durumunu kontrol et
    if check_service_running php${VERSION}-fpm; then
        log_success "PHP ${VERSION}-FPM çalışıyor"
    else
        log_warning "PHP ${VERSION}-FPM başlatılamadı (systemd gerekli)"
    fi
    
    # PHP-FPM yapılandırması
    PHP_FPM_CONF="/etc/php/${VERSION}/fpm/php-fpm.conf"
    PHP_FPM_POOL="/etc/php/${VERSION}/fpm/pool.d/www.conf"
    
    # PHP-FPM pool ayarları (optimize edilmiş)
    cat > "$PHP_FPM_POOL" << EOF
[www]
user = www-data
group = www-data
listen = /var/run/php/php${VERSION}-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500

php_admin_value[error_log] = /var/log/php${VERSION}-fpm.log
php_admin_flag[log_errors] = on
EOF
    
    # PHP.ini optimizasyonları
    PHP_INI="/etc/php/${VERSION}/fpm/php.ini"
    
    # Memory limit
    sed -i "s/memory_limit = .*/memory_limit = 256M/" "$PHP_INI"
    
    # Upload limits
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" "$PHP_INI"
    sed -i "s/post_max_size = .*/post_max_size = 100M/" "$PHP_INI"
    
    # Execution time
    sed -i "s/max_execution_time = .*/max_execution_time = 300/" "$PHP_INI"
    
    # OPcache
    sed -i "s/;opcache.enable=.*/opcache.enable=1/" "$PHP_INI"
    sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=256/" "$PHP_INI"
    sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=16/" "$PHP_INI"
    sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/" "$PHP_INI"
    
    # Timezone
    sed -i "s/;date.timezone =.*/date.timezone = Europe\/Istanbul/" "$PHP_INI"
    
    # Servisi yeniden başlat
    systemctl_safe restart php${VERSION}-fpm
    
    log_success "PHP $VERSION kuruldu ve yapılandırıldı"
done

# Composer kurulumu
log_info "Composer kuruluyor..."
EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    log_error "Composer kurulum dosyası bozuk!"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php
log_success "Composer kuruldu"

# Default PHP versiyonunu ayarla
log_info "Default PHP versiyonu ayarlanıyor: $DEFAULT_VERSION"
update-alternatives --set php /usr/bin/php${DEFAULT_VERSION}

# PHP versiyonlarını listele
log_info "Kurulu PHP versiyonları:"
for VERSION in "${PHP_VERSIONS[@]}"; do
    PHP_VERSION=$(php${VERSION} -v | head -n 1)
    echo "  - $PHP_VERSION"
done

log_success "PHP kurulumu tamamlandı!"

