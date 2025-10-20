# ServerBond Agent

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PHP 8.2+](https://img.shields.io/badge/php-8.2+-777BB4.svg)](https://www.php.net/)
[![Laravel 11](https://img.shields.io/badge/laravel-11-FF2D20.svg)](https://laravel.com)
[![Vue 3](https://img.shields.io/badge/vue-3-42b883.svg)](https://vuejs.org)
[![Ubuntu 24.04](https://img.shields.io/badge/ubuntu-24.04-orange.svg)](https://ubuntu.com/)

Ubuntu 24.04 için gelişmiş multi-site yönetim ve deploy platformu. Tek komutla sunucunuza nginx, MySQL, Redis altyapısını kurup **Laravel 11 + Vue 3** ile modern web dashboard'dan site yönetimi yapabilirsiniz.

🌟 **Laravel Forge** benzeri, tamamen **açık kaynak** ve **ücretsiz** server management çözümü!

## 🚀 Modern Full-Stack Platform

### Backend (Laravel 11)
- ✅ **Laravel 11** - Modern PHP Framework
- ✅ **Eloquent ORM** - Veritabanı işlemleri kolay
- ✅ **Service Pattern** - SOLID prensipleri
- ✅ **Queue & Scheduler** - Native Laravel features
- ✅ **Form Requests** - Güvenli validasyon
- ✅ **API Resources** - Clean responses

### Frontend (Vue 3)
- ✅ **Vue 3** - Progressive JavaScript Framework
- ✅ **Vue Router** - SPA Navigation
- ✅ **Pinia** - State Management
- ✅ **TailwindCSS** - Modern UI Design
- ✅ **Heroicons** - Beautiful Icons
- ✅ **Vite** - Lightning Fast Build Tool

## 🚀 Özellikler

- **Tek Komut Kurulum**: Ubuntu 24.04'e tek shell script ile tam altyapı kurulumu
- **Modern Dashboard**: Vue 3 ile güzel ve hızlı web arayüzü
- **Multi-Site Yönetimi**: Sınırsız sayıda site oluşturma ve yönetme
- **Laravel 11 API**: Modern PHP framework ile güçlü backend
- **Multi PHP Version**: PHP 8.1, 8.2, 8.3 eşzamanlı desteği
- **Git Entegrasyonu**: Repository'lerden otomatik çekme ve deploy
- **Çoklu Site Türü**:
  - Laravel (PHP 8.1, 8.2, 8.3)
  - PHP (Genel PHP uygulamaları)
  - Static (HTML/CSS/JS)
  - Python (FastAPI, Flask, Django)
  - Node.js (Express, Next.js, vb.)
- **Otomatik Nginx Konfigürasyonu**: Her site için optimize edilmiş nginx ayarları
- **Database Yönetimi**: MySQL veritabanı ve kullanıcı oluşturma/yönetme
- **Deploy Sistemi**: Laravel Queue ile arka planda deploy
- **Real-time Monitoring**: CPU, RAM, Disk kullanımını canlı izleme
- **RESTful API**: Laravel 11 tabanlı modern API

## 📋 Gereksinimler

- Ubuntu 24.04 LTS (Önerilir)
- Root erişimi
- İnternet bağlantısı

## ⚡ Hızlı Kurulum

### Tek Komut ile Kurulum

```bash
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

Kurulum tamamlandığında:
- **Dashboard**: http://your-server-ip/
- **API**: http://your-server-ip/api
- **Docs**: http://your-server-ip/api/sites

Kurulum tamamlandığında aşağıdaki servisler otomatik olarak çalışır durumda olacaktır:
- Nginx (Port 80)
- PHP 8.1, 8.2, 8.3 + FPM
- MySQL 8.0
- Redis
- Laravel 11 API + Vue 3 Dashboard (Port 8000 → Nginx Proxy)

## 🎨 Dashboard Özellikleri

### Ana Sayfa
- 📊 Real-time sistem istatistikleri (CPU, RAM, Disk)
- 📈 Site sayısı, deploy sayısı, database sayısı
- 🚀 Son deploymentlar listesi
- 💚 Canlı sistem durumu

### Sayfalar
- 🏠 **Dashboard** - Sistem özeti ve istatistikler
- 🌐 **Sites** - Site listesi ve yönetimi
- 🚀 **Deployments** - Deploy geçmişi ve tracking
- 🗄️ **Databases** - MySQL veritabanı yönetimi
- 🐘 **PHP Versions** - PHP version management
- 💻 **System** - Sistem bilgileri ve servisler

### UI/UX
- ✨ Modern gradient design (Purple → Indigo)
- 📱 Fully responsive
- ⚡ Fast SPA navigation
- 🎨 TailwindCSS styling
- 🔄 Real-time updates
- 💫 Smooth animations

## 📚 Kullanım

### Web Dashboard
```
http://your-server-ip/          # Vue.js Dashboard
http://your-server-ip/sites     # Site yönetimi
http://your-server-ip/deploys   # Deploymentlar
```

### API Endpoints
```bash
# Health check
curl http://localhost:8000/health

# Sites
curl http://localhost:8000/api/sites

# System stats
curl http://localhost:8000/api/system/stats
```

## 🔧 Geliştirme

### Local Development
```bash
cd /opt/serverbond-agent/api

# Vite dev server (Hot Module Replacement)
npm run dev

# Laravel serve
php artisan serve
```

### Production Build
```bash
cd /opt/serverbond-agent/api
npm run build
```

## 🔐 Güvenlik

- MySQL root şifresi otomatik: `/opt/serverbond-agent/config/.mysql_root_password`
- Laravel APP_KEY otomatik: `/opt/serverbond-agent/api/.env`
- Firewall (UFW) otomatik
- PHP-FPM pool izolasyonu

## 📊 Teknoloji Stack'i

- **Backend**: Laravel 11 + PHP 8.2+
- **Frontend**: Vue 3 + Vite
- **Database**: MySQL 8.0 + Eloquent ORM
- **Cache**: Redis 7.0
- **Web Server**: Nginx 1.24
- **Styling**: TailwindCSS 3
- **Icons**: Heroicons
- **State**: Pinia
- **HTTP**: Axios

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

**ServerBond Agent** - Laravel 11 + Vue 3 ile professional server management! 🚀

[![GitHub stars](https://img.shields.io/github/stars/beyazitkolemen/serverbond-agent?style=social)](https://github.com/beyazitkolemen/serverbond-agent/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/beyazitkolemen/serverbond-agent?style=social)](https://github.com/beyazitkolemen/serverbond-agent/network/members)
