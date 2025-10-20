#!/bin/bash

#############################################
# ServerBond Agent - Ana Kurulum Scripti
# Ubuntu 24.04 için tasarlanmıştır
#############################################

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
  ____                          ____                  _ 
 / ___|  ___ _ ____   _____ _ _| __ )  ___  _ __   __| |
 \___ \ / _ \ '__\ \ / / _ \ '__|  _ \ / _ \| '_ \ / _` |
  ___) |  __/ |   \ V /  __/ |  | |_) | (_) | | | | (_| |
 |____/ \___|_|    \_/ \___|_|  |____/ \___/|_| |_|\__,_|
                                                          
     Multi-Site Management Agent v1.0
EOF
echo -e "${NC}"

# Log fonksiyonları (en başta tanımlanmalı)
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Değişkenler
INSTALL_DIR="/opt/serverbond-agent"
GITHUB_REPO="beyazitkolemen/serverbond-agent"
REPO_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
PYTHON_VERSION="3.12"

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Bu script root olarak çalıştırılmalıdır!${NC}" 
   exit 1
fi

# Systemd kontrolü
check_systemd() {
    if ! pidof systemd > /dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Ortam kontrolü
detect_environment() {
    if [ -f /proc/version ]; then
        if grep -qi microsoft /proc/version; then
            echo "wsl"
            return
        fi
    fi
    
    if [ -f /.dockerenv ]; then
        echo "docker"
        return
    fi
    
    echo "native"
}

ENVIRONMENT=$(detect_environment)

if ! check_systemd && [ "$ENVIRONMENT" != "native" ]; then
    log_error "Bu script systemd gerektiriyor!"
    echo ""
    echo -e "${YELLOW}Tespit edilen ortam: $ENVIRONMENT${NC}"
    echo ""
    echo "Çözümler:"
    
    if [ "$ENVIRONMENT" = "wsl" ]; then
        echo "  • WSL2 kullanıyorsanız, systemd'yi etkinleştirin:"
        echo "    1. /etc/wsl.conf dosyası oluşturun:"
        echo "       sudo nano /etc/wsl.conf"
        echo ""
        echo "    2. Şu içeriği ekleyin:"
        echo "       [boot]"
        echo "       systemd=true"
        echo ""
        echo "    3. WSL'i yeniden başlatın:"
        echo "       wsl --shutdown"
        echo ""
    elif [ "$ENVIRONMENT" = "docker" ]; then
        echo "  • Docker container'da systemd destekli bir imaj kullanın"
        echo "  • Veya Docker Compose ile privileged mode kullanın"
        echo ""
    fi
    
    echo "  • Normal bir Ubuntu 24.04 sunucusunda çalıştırın"
    echo ""
    
    read -p "Yine de devam etmek istiyor musunuz? (Bazı servisler çalışmayabilir) (e/h): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ee]$ ]]; then
        exit 1
    fi
    
    log_step "Systemd olmadan devam ediliyor. Bazı servisler manuel başlatılmalı!"
    SKIP_SYSTEMD=true
else
    SKIP_SYSTEMD=false
fi

# SKIP_SYSTEMD'yi export et ki child script'ler görebilsin
export SKIP_SYSTEMD

# Ubuntu versiyon kontrolü
if [ -f /etc/os-release ]; then
    . /etc/os-release
    UBUNTU_VERSION=$VERSION_ID
    
    if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
        log_step "Bu script Ubuntu 24.04 için optimize edilmiştir. Mevcut versiyon: $UBUNTU_VERSION"
        read -p "Devam etmek istiyor musunuz? (e/h): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ee]$ ]]; then
            exit 1
        fi
    fi
else
    log_step "Ubuntu versiyonu tespit edilemedi. Devam ediliyor..."
fi

# Kurulum dizinini oluştur
log_step "Kurulum dizini oluşturuluyor..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Sistem güncellemesi
log_step "Sistem güncelleniyor..."

# Debconf'u non-interactive modda ayarla
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# APT uyarılarını sustur
apt-get update -qq 2>&1 | grep -v "debconf: unable" | grep -v "debconf: falling" | grep -v "frontend" || true
apt-get upgrade -y -qq 2>&1 | grep -v "debconf: unable" | grep -v "debconf: falling" | grep -v "frontend" || true

# Temel paketleri yükle
log_step "Temel paketler yükleniyor..."

# Debconf'u non-interactive olarak ayarla
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get install -y -qq \
    curl \
    wget \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    ufw \
    openssl \
    jq \
    build-essential \
    pkg-config \
    libssl-dev \
    dialog \
    apt-utils

# Scripts dizinini oluştur ve scriptleri indir
log_step "Kurulum scriptleri indiriliyor..."
mkdir -p scripts

# Common.sh'ı önce oluştur
cat > scripts/common.sh << 'COMMON_SCRIPT'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Systemd servis yönetimi (hata kontrolü ile)
systemctl_safe() {
    local action=$1
    local service=$2
    
    if [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
        log_step "Systemd yok: $action $service atlandı"
        return 0
    fi
    
    if ! command -v systemctl &> /dev/null; then
        log_step "systemctl bulunamadı: $action $service atlandı"
        return 0
    fi
    
    if systemctl $action $service 2>&1; then
        return 0
    else
        log_step "Systemd komutu başarısız: $action $service"
        return 1
    fi
}

# Paket kurulum kontrolü
check_package_installed() {
    local package=$1
    dpkg -l | grep -q "^ii  $package " 2>/dev/null
}

# Servis durumu kontrolü
check_service_running() {
    local service=$1
    
    if [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
        log_step "Systemd yok: $service durumu kontrol edilemiyor"
        return 0
    fi
    
    if systemctl is-active --quiet $service 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Port kontrolü
check_port_available() {
    local port=$1
    if ! command -v nc &> /dev/null; then
        # netcat yoksa varsayılan olarak uygun kabul et
        return 0
    fi
    
    if nc -z localhost $port 2>/dev/null; then
        return 1  # Port kullanımda
    else
        return 0  # Port müsait
    fi
}

# Hata ile çıkış
die() {
    log_error "$1"
    exit 1
}

# Başarı mesajı ile çıkış
success_exit() {
    log_success "$1"
    exit 0
}
COMMON_SCRIPT

chmod +x scripts/common.sh

# Eğer local git repo varsa oradan kopyala, yoksa wget ile indir
if [ -d "/tmp/serverbond-agent" ]; then
    cp -r /tmp/serverbond-agent/* "$INSTALL_DIR/"
else
    # Python kurulum scripti
    cat > scripts/install-python.sh << 'PYTHON_SCRIPT'
#!/bin/bash
set -e

# Common.sh'ı source et
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
elif [ -f "/opt/serverbond-agent/scripts/common.sh" ]; then
    source /opt/serverbond-agent/scripts/common.sh
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
fi

log_step "Python 3.12 kuruluyor..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq python3.12 python3.12-venv python3-pip python3.12-dev build-essential 2>&1 | grep -v "debconf:" || true
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 2>/dev/null || true
log_success "Python 3.12 kuruldu"
PYTHON_SCRIPT

    # Nginx kurulum scripti
    cat > scripts/install-nginx.sh << 'NGINX_SCRIPT'
#!/bin/bash
set -e

# Common.sh'ı source et
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
elif [ -f "/opt/serverbond-agent/scripts/common.sh" ]; then
    source /opt/serverbond-agent/scripts/common.sh
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
fi

log_step "Nginx kuruluyor..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq nginx 2>&1 | grep -v "debconf:" || true

systemctl_safe enable nginx
systemctl_safe start nginx

# Firewall kuralı (varsa)
if command -v ufw &> /dev/null; then
    ufw allow 'Nginx Full' 2>/dev/null || log_step "UFW kuralı eklenemedi"
fi

# Default site konfigürasyonu - Laravel + Vue Dashboard
log_step "Nginx default site yapılandırılıyor (Laravel + Vue)..."
cat > /etc/nginx/sites-available/default << 'CONFEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /opt/serverbond-agent/api/public;
    index index.php index.html;
    
    server_name _;
    
    access_log /var/log/nginx/serverbond-access.log;
    error_log /var/log/nginx/serverbond-error.log;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
    
    # Laravel + Vue.js SPA
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # PHP-FPM
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }
    
    # Deny hidden files
    location ~ /\.(?!well-known).* {
        deny all;
    }
    
    # Static assets caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
CONFEOF

# Nginx'i reload et
systemctl_safe reload nginx || true

# Test
if check_service_running nginx; then
    log_success "Nginx başarıyla kuruldu ve çalışıyor"
    log_step "Default page: http://$(hostname -I | awk '{print $1}')/"
elif [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
    log_step "Nginx kuruldu (systemd olmadan çalıştırma gerekli)"
else
    log_error "Nginx kurulumu başarısız!"
    exit 1
fi
NGINX_SCRIPT

    # MySQL kurulum scripti
    cat > scripts/install-mysql.sh << 'MYSQL_SCRIPT'
#!/bin/bash
set -e

# Common.sh'ı source et
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
elif [ -f "/opt/serverbond-agent/scripts/common.sh" ]; then
    source /opt/serverbond-agent/scripts/common.sh
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
fi

log_step "MySQL 8.0 kuruluyor..."

# Root şifresi oluştur
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)

# MySQL kurulumu
export DEBIAN_FRONTEND=noninteractive

# Debconf ile root şifresini preseed et (eski MySQL versiyonları için)
echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections 2>/dev/null || true
echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections 2>/dev/null || true

apt-get install -y -qq mysql-server 2>&1 | grep -v "debconf:" | grep -v "falling back" || true

# MySQL socket dizinini oluştur ve izinleri ayarla
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
chmod 755 /var/run/mysqld

# MySQL data dizini izinlerini kontrol et
chown -R mysql:mysql /var/lib/mysql
chmod 750 /var/lib/mysql

# MySQL log dizini
mkdir -p /var/log/mysql
chown mysql:mysql /var/log/mysql
chmod 750 /var/log/mysql

# MySQL'i başlat
systemctl_safe enable mysql

# MySQL'i başlatmayı dene
log_step "MySQL başlatılıyor..."
if systemctl_safe start mysql; then
    log_success "MySQL servisi başlatıldı"
else
    log_step "MySQL servisi başlatılamadı, yeniden deneniyor..."
    
    # AppArmor sorununu çöz (varsa)
    if command -v aa-complain &> /dev/null; then
        aa-complain /usr/sbin/mysqld 2>/dev/null || true
    fi
    
    # Bir kez daha dene
    systemctl_safe restart mysql || log_step "MySQL hala başlamıyor"
fi

sleep 5

# MySQL çalışıyor mu kontrol et
if check_service_running mysql; then
    log_step "MySQL çalışıyor, güvenlik ayarları yapılıyor..."
    
    # Root şifresini kaydet (önce)
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
    
    # Ubuntu 24.04'te MySQL 8.0 varsayılan auth_socket kullanır
    # Alternatif yöntem 1: mysql -u root ile (şifresiz, auth_socket)
    log_step "Yöntem 1: Doğrudan root bağlantısı deneniyor..."
    
    if mysql -u root -e "SELECT 1;" > /dev/null 2>&1; then
        # Şifresiz bağlanabiliyoruz, şifreyi ayarla
        mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        
        if [ $? -eq 0 ]; then
            log_success "MySQL güvenlik ayarları tamamlandı (Yöntem 1)"
        fi
    else
        # Yöntem 2: systemd unit override ile skip-grant-tables
        log_step "Yöntem 2: Systemd override ile deneniyor..."
        
        systemctl_safe stop mysql
        sleep 2
        
        # Systemd override dizini oluştur
        mkdir -p /etc/systemd/system/mysql.service.d
        
        # Skip-grant-tables override
        cat > /etc/systemd/system/mysql.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/mysqld --skip-grant-tables --skip-networking
EOF
        
        # Systemd'yi yenile ve başlat
        systemctl daemon-reload
        systemctl_safe start mysql
        sleep 5
        
        # Şifreyi ayarla
        mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        
        # Override'ı kaldır ve normal başlat
        rm -f /etc/systemd/system/mysql.service.d/override.conf
        systemctl daemon-reload
        systemctl_safe restart mysql
        sleep 3
        
        log_success "MySQL güvenlik ayarları tamamlandı (Yöntem 2)"
    fi
    
    # Şifre ile test et
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" > /dev/null 2>&1; then
        MYSQL_VERSION=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" -sN 2>/dev/null)
        log_success "MySQL root şifresi doğrulandı ✓"
        log_step "MySQL Versiyonu: $MYSQL_VERSION"
    else
        log_step "MySQL kuruldu ancak şifre doğrulanamadı"
        log_step "Şifreyi manuel olarak ayarlamak için:"
        echo "  mysql -u root  # (şifresiz deneyebilirsiniz)"
        echo "  ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your-password';"
    fi
else
    log_step "MySQL kuruldu ancak başlatılamadı"
    
    # Root şifresini kaydet (yine de)
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
    
    log_step "MySQL sorun giderme adımları:"
    echo ""
    echo "1. Hata loglarını kontrol edin:"
    echo "   sudo journalctl -u mysql -n 50"
    echo "   sudo tail -f /var/log/mysql/error.log"
    echo ""
    echo "2. MySQL'i manuel başlatın:"
    echo "   sudo systemctl start mysql"
    echo "   sudo systemctl status mysql"
    echo ""
    echo "3. AppArmor sorunuysa:"
    echo "   sudo aa-complain /usr/sbin/mysqld"
    echo "   sudo systemctl restart mysql"
    echo ""
    echo "4. Konfigürasyon test edin:"
    echo "   sudo mysqld --validate-config"
    echo ""
    
    log_step "Kurulum MySQL olmadan devam ediyor..."
fi
MYSQL_SCRIPT

    # Redis kurulum scripti
    cat > scripts/install-redis.sh << 'REDIS_SCRIPT'
#!/bin/bash
set -e

# Common.sh'ı source et
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
elif [ -f "/opt/serverbond-agent/scripts/common.sh" ]; then
    source /opt/serverbond-agent/scripts/common.sh
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
fi

log_step "Redis kuruluyor..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq redis-server 2>&1 | grep -v "debconf:" || true

# Redis yapılandırması
if [ "${SKIP_SYSTEMD:-false}" != "true" ]; then
    sed -i 's/supervised no/supervised systemd/' /etc/redis/redis.conf
else
    log_step "Systemd yok, Redis supervised mode atlandı"
fi
sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf 2>/dev/null || true
sed -i 's/bind 127.0.0.1 -::1/bind 127.0.0.1/' /etc/redis/redis.conf 2>/dev/null || true

systemctl_safe enable redis-server
systemctl_safe restart redis-server

if check_service_running redis-server; then
    log_success "Redis başarıyla kuruldu ve çalışıyor"
elif [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
    log_step "Redis kuruldu (systemd olmadan çalıştırma gerekli)"
else
    log_error "Redis kurulumu başarısız!"
    exit 1
fi
REDIS_SCRIPT

    # PHP kurulum scripti
    cat > scripts/install-php.sh << 'PHP_SCRIPT'
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

log_step "PHP kurulumu başlıyor..."

# Ondrej PPA ekle
log_step "Ondrej PPA repository ekleniyor..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq software-properties-common 2>&1 | grep -v "debconf:" || true
add-apt-repository -y ppa:ondrej/php 2>&1 | grep -v "debconf:" || true
apt-get update -qq 2>&1 | grep -v "debconf:" || true

# Her PHP versiyonu için kurulum
for VERSION in "${PHP_VERSIONS[@]}"; do
    log_step "PHP $VERSION kuruluyor..."
    
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
        log_step "PHP ${VERSION}-FPM başlatılamadı (systemd gerekli)"
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
log_step "Composer kuruluyor..."
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
log_step "Default PHP versiyonu ayarlanıyor: $DEFAULT_VERSION"
update-alternatives --set php /usr/bin/php${DEFAULT_VERSION}

# PHP versiyonlarını listele
log_step "Kurulu PHP versiyonları:"
for VERSION in "${PHP_VERSIONS[@]}"; do
    PHP_VERSION=$(php${VERSION} -v | head -n 1)
    echo "  - $PHP_VERSION"
done

log_success "PHP kurulumu tamamlandı!"
PHP_SCRIPT

    # Node.js kurulum scripti
    cat > scripts/install-nodejs.sh << 'NODEJS_SCRIPT'
#!/bin/bash

#############################################
# Node.js ve NPM Kurulum Scripti
# Node.js 20.x LTS versiyonu
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

NODE_VERSION="20"

log_step "Node.js ${NODE_VERSION}.x kuruluyor..."

# NodeSource repository'sini ekle
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

# Node.js ve NPM kur
apt-get install -y -qq nodejs

# Yarn kur (opsiyonel)
npm install -g yarn --quiet

# PM2 kur (process manager)
npm install -g pm2 --quiet

# Node.js versiyonunu kontrol et
NODE_INSTALLED_VERSION=$(node -v)
NPM_VERSION=$(npm -v)

log_success "Node.js kuruldu: $NODE_INSTALLED_VERSION"
log_success "NPM kuruldu: v$NPM_VERSION"
log_success "Yarn kuruldu: $(yarn -v)"
log_success "PM2 kuruldu: $(pm2 -v)"

# PM2 startup script
if [ "${SKIP_SYSTEMD:-false}" = "false" ]; then
    pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || log_step "PM2 startup ayarlanamadı"
    log_step "PM2 systemd entegrasyonu tamamlandı"
fi
NODEJS_SCRIPT

    # Certbot kurulum scripti
    cat > scripts/install-certbot.sh << 'CERTBOT_SCRIPT'
#!/bin/bash

#############################################
# Certbot (Let's Encrypt) Kurulum Scripti
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

log_step "Certbot kuruluyor..."

# Certbot ve Nginx plugin'i kur
apt-get install -y -qq certbot python3-certbot-nginx

# Certbot versiyonunu kontrol et
CERTBOT_VERSION=$(certbot --version 2>&1 | head -n 1)

log_success "Certbot kuruldu: $CERTBOT_VERSION"

# Auto-renewal timer'ı etkinleştir (systemd varsa)
if [ "${SKIP_SYSTEMD:-false}" = "false" ]; then
    if systemctl list-unit-files | grep -q certbot.timer; then
        systemctl_safe enable certbot.timer
        systemctl_safe start certbot.timer
        log_success "Certbot auto-renewal timer etkinleştirildi"
    else
        # Cron job ekle
        CRON_CMD="0 0,12 * * * root certbot renew --quiet"
        if ! grep -q "certbot renew" /etc/crontab 2>/dev/null; then
            echo "$CRON_CMD" >> /etc/crontab
            log_success "Certbot cron job eklendi"
        fi
    fi
else
    log_step "Systemd yok - Certbot auto-renewal manuel ayarlanmalı"
fi

log_step "SSL sertifikası almak için:"
echo "  sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com"
CERTBOT_SCRIPT

    # Supervisor kurulum scripti
    cat > scripts/install-supervisor.sh << 'SUPERVISOR_SCRIPT'
#!/bin/bash

#############################################
# Supervisor Kurulum Scripti
# Queue/Worker process manager
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

log_step "Supervisor kuruluyor..."

# Supervisor'ı kur
apt-get install -y -qq supervisor

# Supervisor'ı etkinleştir ve başlat
systemctl_safe enable supervisor
systemctl_safe start supervisor

# Config dizinini oluştur
mkdir -p /etc/supervisor/conf.d

# Supervisor versiyonunu kontrol et
SUPERVISOR_VERSION=$(supervisorctl version 2>/dev/null || echo "unknown")

if check_service_running supervisor; then
    log_success "Supervisor kuruldu ve çalışıyor: $SUPERVISOR_VERSION"
elif [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
    log_step "Supervisor kuruldu (systemd olmadan çalıştırma gerekli)"
else
    log_step "Supervisor kuruldu ancak başlatılamadı"
fi

log_step "Worker konfigürasyonları /etc/supervisor/conf.d/ dizinine eklenebilir"
SUPERVISOR_SCRIPT

    # Extras kurulum scripti
    cat > scripts/install-extras.sh << 'EXTRAS_SCRIPT'
#!/bin/bash

#############################################
# Ekstra Araçlar Kurulum Scripti
# Monitoring, debugging ve utility tools
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

log_step "Ekstra araçlar kuruluyor..."

# System monitoring ve debugging tools
apt-get install -y -qq \
    htop \
    iotop \
    iftop \
    ncdu \
    tree \
    net-tools \
    dnsutils \
    telnet \
    netcat-openbsd \
    zip \
    unzip \
    rsync \
    vim \
    nano \
    screen \
    tmux

# Networking tools
apt-get install -y -qq \
    traceroute \
    mtr \
    iputils-ping \
    curl \
    wget

# Fail2ban (brute-force protection)
log_step "Fail2ban kuruluyor..."
apt-get install -y -qq fail2ban

# Fail2ban'i yapılandır
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
EOF

systemctl_safe enable fail2ban
systemctl_safe restart fail2ban

if check_service_running fail2ban; then
    log_success "Fail2ban çalışıyor"
else
    log_step "Fail2ban başlatılamadı"
fi

# Logrotate konfigürasyonu
cat > /etc/logrotate.d/serverbond-agent << 'EOF'
/opt/serverbond-agent/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
}
EOF

log_success "Ekstra araçlar kuruldu"
log_step "Kurulu araçlar:"
echo "  - htop, iotop, iftop: System monitoring"
echo "  - ncdu: Disk usage analyzer"
echo "  - fail2ban: Brute-force protection"
echo "  - vim, nano: Text editors"
echo "  - screen, tmux: Terminal multiplexers"
echo "  - Logrotate: Log management"
EXTRAS_SCRIPT

fi

# Scriptleri çalıştırılabilir yap
chmod +x scripts/*.sh

# Servis kurulumları
log_step "=== Temel Servisler Kuruluyor ==="
echo ""

log_step "1/8: Python kuruluyor..."
bash scripts/install-python.sh
echo ""

log_step "2/8: Nginx kuruluyor..."
bash scripts/install-nginx.sh
echo ""

log_step "3/8: PHP Multi-Version kuruluyor..."
bash scripts/install-php.sh
echo ""

log_step "4/8: MySQL kuruluyor..."
bash scripts/install-mysql.sh
echo ""

log_step "5/8: Redis kuruluyor..."
bash scripts/install-redis.sh
echo ""

log_step "6/8: Node.js kuruluyor..."
bash scripts/install-nodejs.sh
echo ""

log_step "7/8: Certbot (Let's Encrypt) kuruluyor..."
bash scripts/install-certbot.sh
echo ""

log_step "8/8: Supervisor kuruluyor..."
bash scripts/install-supervisor.sh
echo ""

log_step "=== Ekstra Araçlar Kuruluyor ==="
bash scripts/install-extras.sh
echo ""

# Config dizinleri oluştur
mkdir -p config
mkdir -p logs
mkdir -p sites
mkdir -p backups

# Laravel API kurulumu
if [ -d "api" ] && command -v composer &> /dev/null; then
    log_step "Laravel API kuruluyor..."
    
    cd api
    
    # Composer install
    log_step "Composer bağımlılıkları yükleniyor..."
    composer install --no-dev --optimize-autoloader --no-interaction --quiet
    
    # .env oluştur
    if [ ! -f .env ]; then
        cp .env.example .env
        
        # APP_KEY generate
        php artisan key:generate --force
        
        # MySQL şifresini ayarla
        if [ -f "$INSTALL_DIR/config/.mysql_root_password" ]; then
            MYSQL_PASS=$(cat "$INSTALL_DIR/config/.mysql_root_password")
            sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${MYSQL_PASS}/" .env
        fi
        
        log_success ".env dosyası oluşturuldu"
    fi
    
    # Database oluştur
    if [ -f "$INSTALL_DIR/config/.mysql_root_password" ]; then
        log_step "Laravel database oluşturuluyor..."
        MYSQL_PASS=$(cat "$INSTALL_DIR/config/.mysql_root_password")
        mysql -u root -p"$MYSQL_PASS" <<EOF 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS serverbond_agent CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON serverbond_agent.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
EOF
        log_success "Laravel database hazır"
    fi
    
    # Migration çalıştır
    log_step "Laravel migration'ları çalıştırılıyor..."
    php artisan migrate --force --quiet 2>/dev/null || log_step "Laravel migration hatası (MySQL gerekli)"
    
    # Cache optimize et
    log_step "Laravel cache optimize ediliyor..."
    php artisan config:cache --quiet
    php artisan route:cache --quiet
    
    # Vue.js dashboard build et
    if [ -f "package.json" ]; then
        log_step "Vue.js dashboard build ediliyor..."
        npm install --silent 2>&1 | grep -v "npm warn" || true
        npm run build --silent 2>&1 | grep -v "npm warn" || true
        log_success "Vue.js dashboard build edildi"
    fi
    
    cd "$INSTALL_DIR"
    
    log_success "Laravel API ve Vue.js Dashboard kuruldu"
fi

# API yapılandırması
log_step "API yapılandırılıyor..."

# API yapılandırma dosyası
cat > config/agent.conf << EOF
[paths]
sites_dir = $INSTALL_DIR/sites
nginx_sites_available = /etc/nginx/sites-available
nginx_sites_enabled = /etc/nginx/sites-enabled
logs_dir = $INSTALL_DIR/logs
backups_dir = $INSTALL_DIR/backups

[mysql]
host = localhost
port = 3306
root_password_file = $INSTALL_DIR/config/.mysql_root_password

[redis]
host = localhost
port = 6379
db = 0
EOF

log_success "API yapılandırması tamamlandı"
log_step "Laravel API Nginx üzerinden çalışıyor (Port 80)"

# Kurulum özeti
echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Kurulum Başarıyla Tamamlandı!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}Kurulum Dizini:${NC} $INSTALL_DIR"
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "your-server-ip")
echo -e "${BLUE}Dashboard:${NC} http://${SERVER_IP}/"
echo -e "${BLUE}API:${NC} http://${SERVER_IP}/api"
echo
echo -e "${BLUE}Servisler:${NC}"
if [ "$SKIP_SYSTEMD" = "false" ]; then
    echo "  - Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
    echo "  - PHP 8.2-FPM: $(systemctl is-active php8.2-fpm 2>/dev/null || echo 'unknown')"
    echo "  - MySQL: $(systemctl is-active mysql 2>/dev/null || echo 'unknown')"
    echo "  - Redis: $(systemctl is-active redis-server 2>/dev/null || echo 'unknown')"
else
    echo "  - Systemd yok - servisler manuel kontrol edilmeli"
fi
echo
echo -e "${BLUE}Yapılandırma:${NC}"
echo "  - Agent Config: $INSTALL_DIR/config/agent.conf"
echo "  - MySQL Root Password: $INSTALL_DIR/config/.mysql_root_password"
echo
echo -e "${BLUE}Kurulu Yazılımlar:${NC}"
echo "  - PHP: $(php -v 2>/dev/null | head -n 1 | awk '{print $2}')"
echo "  - Laravel: $(cd api && php artisan --version 2>/dev/null | awk '{print $3}' || echo 'N/A')"
echo "  - Composer: $(composer --version 2>/dev/null | awk '{print $3}' || echo 'N/A')"
echo "  - Node.js: $(node -v 2>/dev/null || echo 'N/A')"
echo "  - Nginx: $(nginx -v 2>&1 | awk '{print $3}' | cut -d '/' -f2)"
echo "  - MySQL: $(mysql --version 2>/dev/null | awk '{print $5}' | cut -d ',' -f1)"
echo "  - Redis: $(redis-server --version 2>/dev/null | awk '{print $3}' | cut -d '=' -f2)"
echo
echo -e "${YELLOW}Önemli Notlar:${NC}"
echo "  - Dashboard: http://localhost/"
echo "  - API: http://localhost/api"
echo "  - Nginx durumu: systemctl status nginx"
echo "  - PHP-FPM durumu: systemctl status php8.2-fpm"
echo "  - MySQL şifresi: $INSTALL_DIR/config/.mysql_root_password"
echo ""
echo -e "${YELLOW}SSL Kurulumu:${NC}"
echo "  sudo certbot --nginx -d yourdomain.com"
echo ""
echo -e "${YELLOW}Geliştirme:${NC}"
echo "  cd $INSTALL_DIR/api"
echo "  npm run dev          # Vite dev server (HMR)"
echo "  php artisan queue:work  # Queue worker"
echo
log_success "ServerBond Agent hazır!"

