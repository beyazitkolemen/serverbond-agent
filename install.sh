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
    
    log_warning "Systemd olmadan devam ediliyor. Bazı servisler manuel başlatılmalı!"
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
        log_warning "Bu script Ubuntu 24.04 için optimize edilmiştir. Mevcut versiyon: $UBUNTU_VERSION"
        read -p "Devam etmek istiyor musunuz? (e/h): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ee]$ ]]; then
            exit 1
        fi
    fi
else
    log_warning "Ubuntu versiyonu tespit edilemedi. Devam ediliyor..."
fi

# Kurulum dizinini oluştur
log_info "Kurulum dizini oluşturuluyor..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Sistem güncellemesi
log_info "Sistem güncelleniyor..."
apt-get update -qq
apt-get upgrade -y -qq

# Temel paketleri yükle
log_info "Temel paketler yükleniyor..."
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
    libssl-dev

# Scripts dizinini oluştur ve scriptleri indir
log_info "Kurulum scriptleri indiriliyor..."
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
        log_warning "Systemd yok: $action $service atlandı"
        return 0
    fi
    
    if ! command -v systemctl &> /dev/null; then
        log_warning "systemctl bulunamadı: $action $service atlandı"
        return 0
    fi
    
    if systemctl $action $service 2>&1; then
        return 0
    else
        log_warning "Systemd komutu başarısız: $action $service"
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
        log_warning "Systemd yok: $service durumu kontrol edilemiyor"
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

log_info "Python 3.12 kuruluyor..."
apt-get install -y -qq python3.12 python3.12-venv python3-pip python3.12-dev build-essential
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

log_info "Nginx kuruluyor..."
apt-get install -y -qq nginx

systemctl_safe enable nginx
systemctl_safe start nginx

# Firewall kuralı (varsa)
if command -v ufw &> /dev/null; then
    ufw allow 'Nginx Full' 2>/dev/null || log_warning "UFW kuralı eklenemedi"
fi

# Test
if check_service_running nginx; then
    log_success "Nginx başarıyla kuruldu ve çalışıyor"
elif [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
    log_warning "Nginx kuruldu (systemd olmadan çalıştırma gerekli)"
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

log_info "MySQL 8.0 kuruluyor..."

# Root şifresi oluştur
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)

# MySQL kurulumu
export DEBIAN_FRONTEND=noninteractive

# Debconf ile root şifresini preseed et
echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections

apt-get install -y -qq mysql-server

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
systemctl_safe start mysql

# MySQL çalışıyor mu kontrol et
sleep 5

if check_service_running mysql; then
    log_info "MySQL çalışıyor, güvenlik ayarları yapılıyor..."
    
    # Ubuntu 24.04'te MySQL 8.0 auth_socket kullanır
    # Skip-grant-tables yöntemi ile şifre ayarlayalım
    
    # MySQL'i durdur
    systemctl_safe stop mysql
    sleep 2
    
    # Socket dizinini yeniden oluştur
    mkdir -p /var/run/mysqld
    chown mysql:mysql /var/run/mysqld
    chmod 755 /var/run/mysqld
    
    # Geçici olarak grant table'ları atla
    log_info "Geçici MySQL başlatılıyor (güvenlik ayarları için)..."
    mysqld_safe --skip-grant-tables --skip-networking &
    MYSQLD_PID=$!
    
    sleep 5
    
    # Şimdi şifre ayarla
    mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    # mysqld_safe'i durdur
    kill $MYSQLD_PID 2>/dev/null || true
    sleep 2
    
    # Normal MySQL'i başlat
    systemctl_safe start mysql
    sleep 3
    
    # Root şifresini kaydet
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
    
    # Şifre ile test et
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" > /dev/null 2>&1; then
        log_success "MySQL kuruldu ve şifre ayarlandı"
        log_success "Root şifresi: /opt/serverbond-agent/config/.mysql_root_password"
    else
        log_warning "MySQL kuruldu ancak şifre doğrulanamadı"
    fi
else
    log_warning "MySQL kuruldu ancak başlatılamadı (systemd gerekli)"
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
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

log_info "Redis kuruluyor..."
apt-get install -y -qq redis-server

# Redis yapılandırması
if [ "${SKIP_SYSTEMD:-false}" != "true" ]; then
    sed -i 's/supervised no/supervised systemd/' /etc/redis/redis.conf
else
    log_warning "Systemd yok, Redis supervised mode atlandı"
fi
sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf 2>/dev/null || true
sed -i 's/bind 127.0.0.1 -::1/bind 127.0.0.1/' /etc/redis/redis.conf 2>/dev/null || true

systemctl_safe enable redis-server
systemctl_safe restart redis-server

if check_service_running redis-server; then
    log_success "Redis başarıyla kuruldu ve çalışıyor"
elif [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
    log_warning "Redis kuruldu (systemd olmadan çalıştırma gerekli)"
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

log_info "Node.js ${NODE_VERSION}.x kuruluyor..."

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
    pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || log_warning "PM2 startup ayarlanamadı"
    log_info "PM2 systemd entegrasyonu tamamlandı"
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

log_info "Certbot kuruluyor..."

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
    log_warning "Systemd yok - Certbot auto-renewal manuel ayarlanmalı"
fi

log_info "SSL sertifikası almak için:"
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

log_info "Supervisor kuruluyor..."

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
    log_warning "Supervisor kuruldu (systemd olmadan çalıştırma gerekli)"
else
    log_warning "Supervisor kuruldu ancak başlatılamadı"
fi

log_info "Worker konfigürasyonları /etc/supervisor/conf.d/ dizinine eklenebilir"
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

log_info "Ekstra araçlar kuruluyor..."

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
log_info "Fail2ban kuruluyor..."
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
    log_warning "Fail2ban başlatılamadı"
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
log_info "Kurulu araçlar:"
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
log_info "=== Temel Servisler Kuruluyor ==="
echo ""

log_info "1/8: Python kuruluyor..."
bash scripts/install-python.sh
echo ""

log_info "2/8: Nginx kuruluyor..."
bash scripts/install-nginx.sh
echo ""

log_info "3/8: PHP Multi-Version kuruluyor..."
bash scripts/install-php.sh
echo ""

log_info "4/8: MySQL kuruluyor..."
bash scripts/install-mysql.sh
echo ""

log_info "5/8: Redis kuruluyor..."
bash scripts/install-redis.sh
echo ""

log_info "6/8: Node.js kuruluyor..."
bash scripts/install-nodejs.sh
echo ""

log_info "7/8: Certbot (Let's Encrypt) kuruluyor..."
bash scripts/install-certbot.sh
echo ""

log_info "8/8: Supervisor kuruluyor..."
bash scripts/install-supervisor.sh
echo ""

log_info "=== Ekstra Araçlar Kuruluyor ==="
bash scripts/install-extras.sh
echo ""

# Python sanal ortamı oluştur
log_info "Python sanal ortamı oluşturuluyor..."
python3 -m venv "$INSTALL_DIR/venv"
source "$INSTALL_DIR/venv/bin/activate"

# Config dizini oluştur
mkdir -p config
mkdir -p logs
mkdir -p sites
mkdir -p backups

# Python bağımlılıklarını yükle
log_info "Python bağımlılıkları yükleniyor..."
if [ -f "api/requirements.txt" ]; then
    pip install --quiet --upgrade pip
    pip install --quiet -r api/requirements.txt
fi

# API yapılandırması
log_info "API yapılandırılıyor..."

# API secret key oluştur
API_SECRET_KEY=$(openssl rand -hex 32)

cat > config/agent.conf << EOF
[api]
host = 0.0.0.0
port = 8000
secret_key = $API_SECRET_KEY
debug = false

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

# Systemd servisi oluştur
if [ "$SKIP_SYSTEMD" = "false" ]; then
    log_info "Systemd servisi oluşturuluyor..."
    cat > /etc/systemd/system/serverbond-agent.service << EOF
[Unit]
Description=ServerBond Agent API
After=network.target mysql.service redis-server.service nginx.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python -m uvicorn api.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Servisi etkinleştir ve başlat
    systemctl daemon-reload
    systemctl enable serverbond-agent

    if [ -f "api/main.py" ]; then
        systemctl start serverbond-agent
        log_success "ServerBond Agent servisi başlatıldı"
    else
        log_warning "API dosyaları bulunamadı. Servisi manuel olarak başlatmanız gerekecek."
    fi
else
    log_warning "Systemd yok - servis dosyası oluşturulmadı"
    log_info "API'yi manuel olarak başlatabilirsiniz:"
    echo "  cd $INSTALL_DIR"
    echo "  source venv/bin/activate"
    echo "  uvicorn api.main:app --host 0.0.0.0 --port 8000"
fi

# Firewall yapılandırması
if command -v ufw &> /dev/null; then
    log_info "Firewall yapılandırılıyor..."
    ufw allow 8000/tcp 2>/dev/null || log_warning "UFW kuralı eklenemedi"
    ufw --force enable 2>/dev/null || log_warning "UFW etkinleştirilemedi"
else
    log_warning "UFW bulunamadı, firewall atlandı"
fi

# Kurulum özeti
echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Kurulum Başarıyla Tamamlandı!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}Kurulum Dizini:${NC} $INSTALL_DIR"
echo -e "${BLUE}API Endpoint:${NC} http://$(hostname -I | awk '{print $1}'):8000"
echo -e "${BLUE}API Dokümantasyonu:${NC} http://$(hostname -I | awk '{print $1}'):8000/docs"
echo
echo -e "${BLUE}Servisler:${NC}"
if [ "$SKIP_SYSTEMD" = "false" ]; then
    echo "  - Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
    echo "  - MySQL: $(systemctl is-active mysql 2>/dev/null || echo 'unknown')"
    echo "  - Redis: $(systemctl is-active redis-server 2>/dev/null || echo 'unknown')"
    echo "  - ServerBond Agent: $(systemctl is-active serverbond-agent 2>/dev/null || echo 'unknown')"
else
    echo "  - Systemd yok - servisler manuel başlatılmalı"
fi
echo
echo -e "${BLUE}Yapılandırma:${NC}"
echo "  - Agent Config: $INSTALL_DIR/config/agent.conf"
echo "  - MySQL Root Password: $INSTALL_DIR/config/.mysql_root_password"
echo
echo -e "${BLUE}Kurulu Yazılımlar:${NC}"
echo "  - Python: $(python3 --version 2>/dev/null | awk '{print $2}')"
echo "  - PHP: $(php -v 2>/dev/null | head -n 1 | awk '{print $2}')"
echo "  - Node.js: $(node -v 2>/dev/null || echo 'N/A')"
echo "  - NPM: $(npm -v 2>/dev/null || echo 'N/A')"
echo "  - Composer: $(composer --version 2>/dev/null | awk '{print $3}' || echo 'N/A')"
echo "  - Nginx: $(nginx -v 2>&1 | awk '{print $3}' | cut -d '/' -f2)"
echo "  - MySQL: $(mysql --version 2>/dev/null | awk '{print $5}' | cut -d ',' -f1)"
echo "  - Redis: $(redis-server --version 2>/dev/null | awk '{print $3}' | cut -d '=' -f2)"
echo
echo -e "${YELLOW}Önemli Notlar:${NC}"
echo "  - API'ye erişim için: curl http://localhost:8000/health"
if [ "$SKIP_SYSTEMD" = "false" ]; then
    echo "  - Servisi yeniden başlatmak için: systemctl restart serverbond-agent"
    echo "  - Logları görüntülemek için: journalctl -u serverbond-agent -f"
else
    echo "  - API'yi başlatmak için:"
    echo "    cd $INSTALL_DIR && source venv/bin/activate"
    echo "    uvicorn api.main:app --host 0.0.0.0 --port 8000"
fi
echo "  - SSL için: sudo certbot --nginx -d yourdomain.com"
echo "  - Monitoring: htop, iotop, fail2ban-client status"
echo
log_success "ServerBond Agent hazır!"

