#!/bin/bash

#############################################
# MySQL 8.0 Kurulum Scripti
# Ubuntu 24.04 için optimize edilmiştir
#############################################

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

# Debconf ile root şifresini preseed et (eski MySQL versiyonları için)
echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections

apt-get install -y -qq mysql-server

# MySQL socket dizinini oluştur ve izinleri ayarla
log_info "MySQL dizinleri yapılandırılıyor..."
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
    
    # Şimdi şifre ve güvenlik ayarlarını yap
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

    if [ $? -eq 0 ]; then
        log_success "MySQL güvenlik ayarları tamamlandı"
    else
        log_error "MySQL güvenlik ayarları başarısız!"
    fi
    
    # Geçici mysqld'yi durdur
    kill $MYSQLD_PID 2>/dev/null || true
    killall mysqld 2>/dev/null || true
    sleep 3
    
    # Normal MySQL'i başlat
    systemctl_safe start mysql
    sleep 3
    
    # Root şifresini kaydet
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
    
    # Şifre ile test et
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" > /dev/null 2>&1; then
        log_success "MySQL root şifresi doğrulandı ✓"
        MYSQL_VERSION=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" -sN 2>/dev/null)
        log_info "MySQL Versiyonu: $MYSQL_VERSION"
    else
        log_warning "MySQL root şifresi doğrulanamadı, ancak kurulum tamamlandı"
        log_info "Şifreyi manuel olarak ayarlamak için:"
        echo "  sudo mysql"
        echo "  ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your-password';"
    fi
else
    log_warning "MySQL kuruldu ancak başlatılamadı (systemd gerekli)"
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
fi

