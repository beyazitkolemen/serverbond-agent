# MySQL 8.0 Kurulum ve Yapılandırma

## 🔐 Ubuntu 24.04'te MySQL Authentication

Ubuntu 24.04'te MySQL 8.0 varsayılan olarak root kullanıcısı için `auth_socket` plugin kullanır. Bu durum bazı zorluklar yaratır:

### Sorun
```sql
mysql> SELECT user, host, plugin FROM mysql.user WHERE user='root';
+------+-----------+-------------+
| user | host      | plugin      |
+------+-----------+-------------+
| root | localhost | auth_socket |  ← Şifre ile giriş YOK
+------+-----------+-------------+
```

- ❌ Şifre ile giriş yapılamaz
- ❌ Uzak API'den erişilemez
- ✅ Sadece `sudo mysql` ile giriş

## 🛠️ ServerBond Agent Çözümü

Script otomatik olarak şu adımları uygular:

### 1. MySQL'i Geçici Olarak Skip-Grant-Tables ile Başlat

```bash
# MySQL'i durdur
systemctl stop mysql

# Grant table'ları atla
mysqld_safe --skip-grant-tables --skip-networking &

# Şifre ayarla
mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' 
IDENTIFIED WITH mysql_native_password BY 'güçlü-şifre';
FLUSH PRIVILEGES;
EOF

# Normal MySQL'i başlat
systemctl start mysql
```

### 2. Sonuç

```sql
mysql> SELECT user, host, plugin FROM mysql.user WHERE user='root';
+------+-----------+-----------------------+
| user | host      | plugin                |
+------+-----------+-----------------------+
| root | localhost | mysql_native_password |  ← Şifre ile giriş ✓
+------+-----------+-----------------------+
```

## 🔑 Root Şifre Yönetimi

### Şifre Konumu
```bash
/opt/serverbond-agent/config/.mysql_root_password
```

### Şifreyi Görüntüleme
```bash
sudo cat /opt/serverbond-agent/config/.mysql_root_password
```

### MySQL'e Bağlanma
```bash
# Şifre ile
mysql -u root -p$(cat /opt/serverbond-agent/config/.mysql_root_password)

# Veya interaktif
mysql -u root -p
# Şifre: (dosyadan kopyalayın)
```

## 🔧 Manuel Şifre Ayarlama

Eğer script şifre ayarlayamadıysa manuel olarak:

### Yöntem 1: Sudo ile
```bash
sudo mysql
```

```sql
ALTER USER 'root'@'localhost' 
IDENTIFIED WITH mysql_native_password BY 'yeni-sifre';
FLUSH PRIVILEGES;
```

### Yöntem 2: Skip-Grant-Tables
```bash
# MySQL'i durdur
sudo systemctl stop mysql

# Skip-grant-tables ile başlat
sudo mysqld_safe --skip-grant-tables --skip-networking &

# Şifre ayarla
mysql -u root
```

```sql
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' 
IDENTIFIED WITH mysql_native_password BY 'yeni-sifre';
FLUSH PRIVILEGES;
```

```bash
# mysqld_safe'i durdur
sudo killall mysqld

# Normal MySQL'i başlat
sudo systemctl start mysql

# Test et
mysql -u root -p
```

## 🔐 Güvenlik En İyi Uygulamaları

### 1. Güçlü Şifre Kullanın
```bash
# Otomatik güçlü şifre (ServerBond Agent'ın yaptığı gibi)
openssl rand -base64 32
```

### 2. Remote Root Erişimini Kapatın
```sql
DELETE FROM mysql.user 
WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
FLUSH PRIVILEGES;
```

### 3. Anonim Kullanıcıları Silin
```sql
DELETE FROM mysql.user WHERE User='';
FLUSH PRIVILEGES;
```

### 4. Test Veritabanını Silin
```sql
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
```

### 5. Bind Adresini Sınırlayın
```bash
# /etc/mysql/mysql.conf.d/mysqld.cnf
[mysqld]
bind-address = 127.0.0.1  # Sadece local
```

## 🧪 MySQL Bağlantı Testi

### Python (API'den)
```python
import pymysql

connection = pymysql.connect(
    host='localhost',
    user='root',
    password='şifreniz',
    database='mysql',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

with connection.cursor() as cursor:
    cursor.execute("SELECT VERSION()")
    version = cursor.fetchone()
    print(f"MySQL Version: {version}")

connection.close()
```

### Shell
```bash
# Şifre ile
mysql -u root -p'şifreniz' -e "SELECT VERSION();"

# Dosyadan oku
MYSQL_PASS=$(cat /opt/serverbond-agent/config/.mysql_root_password)
mysql -u root -p"$MYSQL_PASS" -e "SELECT VERSION();"
```

## 📊 Authentication Plugin'leri

| Plugin | Avantaj | Dezavantaj | Kullanım |
|--------|---------|------------|----------|
| `auth_socket` | Yüksek güvenlik (local only) | Şifre yok, API erişimi yok | Ubuntu default |
| `mysql_native_password` | Basit, her yerden erişim | Eski yöntem | ServerBond kullanır |
| `caching_sha2_password` | Modern, güvenli | Bazı istemciler desteklemez | MySQL 8.0+ default |

## 🔄 Plugin Değiştirme

### auth_socket → mysql_native_password
```sql
ALTER USER 'root'@'localhost' 
IDENTIFIED WITH mysql_native_password BY 'şifre';
```

### mysql_native_password → caching_sha2_password
```sql
ALTER USER 'root'@'localhost' 
IDENTIFIED WITH caching_sha2_password BY 'şifre';
```

### Plugin Kontrolü
```sql
SELECT user, host, plugin, authentication_string 
FROM mysql.user 
WHERE user='root';
```

## 🚨 Sorun Giderme

### "Access denied" Hatası
```bash
# 1. Mevcut plugin'i kontrol et
sudo mysql -e "SELECT user, host, plugin FROM mysql.user WHERE user='root';"

# 2. Eğer auth_socket ise, sudo ile bağlan
sudo mysql

# 3. Şifre ayarla
ALTER USER 'root'@'localhost' 
IDENTIFIED WITH mysql_native_password BY 'yeni-şifre';
FLUSH PRIVILEGES;
```

### "Can't connect to MySQL server"
```bash
# MySQL çalışıyor mu?
sudo systemctl status mysql

# Başlat
sudo systemctl start mysql

# Socket dosyası var mı?
ls -la /var/run/mysqld/mysqld.sock
```

### "Too many connections"
```sql
-- Mevcut bağlantıları göster
SHOW PROCESSLIST;

-- Max connections artır
SET GLOBAL max_connections = 200;

-- Kalıcı olarak değiştirmek için /etc/mysql/mysql.conf.d/mysqld.cnf:
[mysqld]
max_connections = 200
```

## ✅ Başarılı Kurulum Kontrol Listesi

- [ ] MySQL 8.0 kuruldu
- [ ] Servis çalışıyor: `systemctl status mysql`
- [ ] Root şifresi ayarlandı
- [ ] Şifre dosyası mevcut: `/opt/serverbond-agent/config/.mysql_root_password`
- [ ] Şifre ile bağlanma testi başarılı
- [ ] Güvenlik ayarları tamamlandı (anonim kullanıcılar silindi)
- [ ] Test database silindi
- [ ] Remote root erişimi kapatıldı

## 📝 Referanslar

- [MySQL 8.0 Authentication](https://dev.mysql.com/doc/refman/8.0/en/authentication-plugins.html)
- [Ubuntu MySQL Documentation](https://ubuntu.com/server/docs/databases-mysql)
- [MySQL Secure Installation](https://dev.mysql.com/doc/refman/8.0/en/mysql-secure-installation.html)

