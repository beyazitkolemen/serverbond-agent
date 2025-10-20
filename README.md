# ServerBond Agent

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PHP 8.4](https://img.shields.io/badge/php-8.4-777BB4.svg)](https://www.php.net/)
[![Ubuntu 24.04](https://img.shields.io/badge/ubuntu-24.04-orange.svg)](https://ubuntu.com/)

Ubuntu 24.04 için gelişmiş server management ve multi-site yönetim platformu. Tek komutla sunucunuza Nginx, PHP 8.4, MySQL, Redis, Node.js ve tüm gerekli altyapıyı kurun.

🌟 **Laravel Forge** benzeri, tamamen **açık kaynak** ve **ücretsiz** server management çözümü!

## 🚀 Özellikler

- **Hızlı Kurulum**: Paralel kurulum ile 2-3x daha hızlı
- **Tek Komut**: Ubuntu 24.04'e tek shell script ile tam altyapı
- **Modern PHP 8.4**: En güncel PHP versiyonu ile optimize edilmiş performans
- **Multi-Site Hazır Altyapı**: Sınırsız site için hazır sunucu ortamı
- **Çoklu Site Türü Desteği**:
  - Laravel (PHP 8.4)
  - PHP (Genel PHP uygulamaları)
  - Static (HTML/CSS/JS)
  - Python (FastAPI, Flask, Django)
  - Node.js (Express, Next.js, vb.)
- **Otomatik Nginx Konfigürasyonu**: Optimize edilmiş web server ayarları
- **Database Stack**: MySQL 8.0 + Redis cache
- **SSL/TLS Desteği**: Let's Encrypt Certbot entegrasyonu
- **Process Management**: Supervisor + PM2
- **Security**: UFW Firewall + Fail2ban
- **Monitoring Tools**: htop, iotop, iftop ve daha fazlası

## 📋 Gereksinimler

- Ubuntu 24.04 LTS (Önerilir)
- Root erişimi
- İnternet bağlantısı

## ⚡ Hızlı Kurulum

### Tek Komut ile Kurulum

```bash
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

Kurulum tamamlandığında aşağıdaki servisler otomatik olarak çalışır durumda olacaktır:
- **Nginx** (Port 80) - Web server
- **PHP 8.4 + FPM** - Modern PHP runtime
- **MySQL 8.0** - Database
- **Redis** - Cache & sessions
- **Node.js 20 + PM2** - Node.js runtime ve process manager
- **Supervisor** - Queue/worker management
- **Certbot** - SSL certificate manager

### ⚡ Performans Özellikleri

- **Paralel Kurulum**: Bağımsız servisler aynı anda kurulur (6 servis paralel)
- **APT Optimizasyonu**: Pipeline ve queue optimizasyonları
- **Shallow Git Clone**: Sadece gerekli dosyalar indirilir
- **Hızlı Network Check**: 1 saniye timeout ile anında kontrol
- **Phase-based Installation**: Bağımlılık yönetimi ile optimal sıralama

## 📚 Kullanım

### Kurulum Sonrası

Kurulum tamamlandıktan sonra sunucunuz multi-site hosting için hazır hale gelir. Şu dizinlerde önemli dosyalar bulunur:

```bash
/opt/serverbond-agent/          # Ana kurulum dizini
/opt/serverbond-agent/config/   # Yapılandırma dosyaları
/opt/serverbond-agent/sites/    # Site dosyaları
/opt/serverbond-agent/logs/     # Log dosyaları
/opt/serverbond-agent/backups/  # Yedekler
```

### Nginx Site Yönetimi

```bash
# Yeni site eklemek için nginx konfigürasyonu
nano /etc/nginx/sites-available/your-site.conf

# Site'ı etkinleştir
ln -s /etc/nginx/sites-available/your-site.conf /etc/nginx/sites-enabled/

# Nginx test ve reload
nginx -t
systemctl reload nginx
```

### PHP Yönetimi

```bash
# PHP-FPM servisi
systemctl status php8.4-fpm
systemctl restart php8.4-fpm
```

## 🔐 Güvenlik

- MySQL root şifresi otomatik oluşturulur: `/opt/serverbond-agent/config/.mysql_root_password`
- UFW Firewall otomatik yapılandırılır
- Fail2ban brute-force koruması
- PHP-FPM pool izolasyonu
- Nginx güvenlik başlıkları

## 📊 Teknoloji Stack'i

- **Web Server**: Nginx 1.24+
- **PHP**: 8.4
- **Database**: MySQL 8.0
- **Cache**: Redis 7.0
- **Node.js**: 20.x LTS
- **Process Managers**: Supervisor + PM2
- **SSL/TLS**: Certbot (Let's Encrypt)
- **Security**: UFW + Fail2ban

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun
3. Commit yapın
4. Push yapın
5. Pull Request açın

## 📝 Lisans

MIT License

## 📧 İletişim

- **GitHub**: [github.com/beyazitkolemen/serverbond-agent](https://github.com/beyazitkolemen/serverbond-agent)
- **Issues**: [github.com/beyazitkolemen/serverbond-agent/issues](https://github.com/beyazitkolemen/serverbond-agent/issues)

## ⭐ Projeyi Beğendiniz Mi?

[⭐ Star on GitHub](https://github.com/beyazitkolemen/serverbond-agent)

---

**ServerBond Agent** - Professional server management için tek komutla tam altyapı! 🚀

[![GitHub stars](https://img.shields.io/github/stars/beyazitkolemen/serverbond-agent?style=social)](https://github.com/beyazitkolemen/serverbond-agent/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/beyazitkolemen/serverbond-agent?style=social)](https://github.com/beyazitkolemen/serverbond-agent/network/members)
