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
    
    # Root şifresini kaydet (önce)
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
    
    # Ubuntu 24.04'te MySQL 8.0 varsayılan auth_socket kullanır
    # Alternatif yöntem 1: mysql -u root ile (şifresiz, auth_socket)
    log_info "MySQL root şifresi ayarlanıyor..."
    
    if mysql -u root -e "SELECT 1;" > /dev/null 2>&1; then
        # Şifresiz bağlanabiliyoruz, şifreyi ayarla
        log_info "Doğrudan bağlantı başarılı, şifre ayarlanıyor..."
        
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
            log_success "MySQL güvenlik ayarları tamamlandı"
        fi
    else
        # Yöntem 2: systemd unit override ile skip-grant-tables
        log_info "Alternatif yöntem deneniyor (systemd override)..."
        
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
        
        log_success "MySQL güvenlik ayarları tamamlandı"
    fi
    
    # Şifre ile test et
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" > /dev/null 2>&1; then
        MYSQL_VERSION=$(mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT VERSION();" -sN 2>/dev/null)
        log_success "MySQL root şifresi doğrulandı ✓"
        log_info "MySQL Versiyonu: $MYSQL_VERSION"
    else
        log_warning "MySQL kuruldu ancak şifre doğrulanamadı"
        log_info "Şifreyi manuel olarak ayarlamak için:"
        echo "  mysql -u root  # (şifresiz deneyebilirsiniz)"
        echo "  ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your-password';"
        echo ""
        echo "Kaydedilen şifre: /opt/serverbond-agent/config/.mysql_root_password"
    fi
else
    log_warning "MySQL kuruldu ancak başlatılamadı (systemd gerekli)"
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
fi

