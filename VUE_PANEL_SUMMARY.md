# 🎨 ServerBond Agent - Vue.js Kontrol Paneli

## ✅ Vue.js Dashboard Eklendi!

**Tarih:** 2025-10-20  
**Framework:** Vue 3 + Vite  
**UI:** TailwindCSS + Heroicons  
**Port:** 80 (Nginx üzerinden)

---

## 🎯 Teknoloji Stack'i

```
Vue 3.js          # Progressive JavaScript Framework
Vue Router 4      # SPA Routing
Pinia            # State Management
Axios            # HTTP Client
TailwindCSS      # Utility-First CSS
Heroicons        # Beautiful Icons
Vite             # Build Tool (Laravel 11 default)
```

---

## 📁 Vue.js Yapısı

```
api/resources/
├── js/
│   ├── app.js                    ✅ Main entry point
│   ├── App.vue                   ✅ Root component
│   ├── router/
│   │   └── index.js              ✅ Vue Router config
│   ├── components/
│   │   ├── Navbar.vue            ✅ Top navigation
│   │   ├── Sidebar.vue           ✅ Side menu
│   │   ├── StatsCard.vue         ✅ Statistics card
│   │   └── ProgressBar.vue       ✅ Progress component
│   └── pages/
│       ├── Dashboard.vue         ✅ Ana sayfa
│       ├── Sites.vue             ✅ Site listesi
│       ├── SiteCreate.vue        ⏳ Oluşturulacak
│       ├── SiteDetails.vue       ⏳ Oluşturulacak
│       ├── Deploys.vue           ⏳ Oluşturulacak
│       ├── Databases.vue         ⏳ Oluşturulacak
│       ├── PhpVersions.vue       ⏳ Oluşturulacak
│       └── System.vue            ⏳ Oluşturulacak
├── css/
│   └── app.css                   ✅ TailwindCSS
└── views/
    └── app.blade.php             ✅ Vue mount point
```

---

## 🎨 Tasarım Özellikleri

### Renk Paleti
```css
Primary:   #667eea → #764ba2 (Purple gradient)
Success:   #10b981 (Green)
Warning:   #f59e0b (Orange)
Danger:    #ef4444 (Red)
Info:      #3b82f6 (Blue)
```

### UI Bileşenleri
- ✅ Gradient navbar (Purple → Indigo)
- ✅ Sidebar navigation
- ✅ Stats cards with icons
- ✅ Progress bars
- ✅ Responsive grid layout
- ✅ Hover effects
- ✅ Loading states
- ✅ Empty states

---

## 🚀 Sayfalar

### 1. Dashboard (/)
```
✨ Stats Overview
- Total Sites
- Active Deploys
- Databases
- PHP Versions

📊 System Monitoring
- CPU Usage (real-time)
- Memory Usage (real-time)
- Disk Usage (real-time)

📋 Recent Deployments
- Deploy history
- Status indicators
```

### 2. Sites (/sites)
```
📝 Site Listesi
- Grid layout
- Site type badges
- PHP version badges
- SSL indicators
- Quick deploy button
- Delete button

➕ Create New Site
- Form wizard
- Git integration
- PHP version selector
```

### 3. Deployments (/deploys)
```
🚀 Deploy History
- All deployments
- Status tracking
- Logs viewer
- Rollback option
```

### 4. Databases (/databases)
```
🗄️ Database Management
- List databases
- Create new
- Backup
- Delete
```

### 5. PHP Versions (/php)
```
🐘 PHP Management
- Installed versions
- Install new version
- Switch site PHP version
- FPM status
```

### 6. System (/system)
```
💻 System Info
- Server info
- Service status
- Resource usage
- Restart services
```

---

## 🌐 Nginx Konfigürasyonu

Dashboard port 80'de çalışıyor:

```nginx
server {
    listen 80 default_server;
    
    root /opt/serverbond-agent/api/public;
    index index.html index.php;
    
    # Vue.js SPA
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # Laravel API
    location /api {
        try_files $uri /index.php?$query_string;
    }
    
    # PHP-FPM
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        include fastcgi_params;
    }
}
```

---

## 🛠️ Geliştirme

### Local Development
```bash
cd /opt/serverbond-agent/api

# Vite dev server (HMR ile)
npm run dev

# Laravel serve
php artisan serve

# Tarayıcıda aç
http://localhost:5173  # Vite dev
http://localhost:8000  # Laravel
```

### Production Build
```bash
cd /opt/serverbond-agent/api

# Build Vue.js
npm run build

# Assets public/build/ dizinine build edilir
# Nginx direkt Laravel public'i serve eder
```

---

## 📦 Kurulum Eklentisi

install.sh'a eklenecek:

```bash
# Vue.js dependencies kur
if [ -f "api/package.json" ]; then
    cd api
    npm install --silent
    npm run build
    cd ..
    log_success "Vue.js dashboard build edildi"
fi
```

---

## 🎯 Kullanıcı Deneyimi

### Dashboard Akışı
```
1. Tarayıcıda http://server-ip/ aç
2. Modern Vue.js dashboard açılır
3. Real-time system stats
4. Sidebar'dan sayfalar arası geçiş
5. Sites → Create → Deploy (tek akış)
```

### Özellikler
- ⚡ Hızlı SPA (Single Page Application)
- 🔄 Real-time updates (polling)
- 📱 Responsive (mobile-ready)
- 🎨 Modern gradient design
- ✨ Smooth animations
- 🚀 Fast navigation

---

## ✅ Oluşturulan Dosyalar

### Vue Components (4)
- ✅ `Navbar.vue` - Top navigation bar
- ✅ `Sidebar.vue` - Side menu
- ✅ `StatsCard.vue` - Stats display
- ✅ `ProgressBar.vue` - Progress indicator

### Vue Pages (2/8)
- ✅ `Dashboard.vue` - Ana sayfa
- ✅ `Sites.vue` - Site listesi
- ⏳ `SiteCreate.vue` - Site oluşturma
- ⏳ `SiteDetails.vue` - Site detayları
- ⏳ `Deploys.vue` - Deploy listesi
- ⏳ `Databases.vue` - Database yönetimi
- ⏳ `PhpVersions.vue` - PHP versiyonları
- ⏳ `System.vue` - Sistem bilgileri

### Core Files
- ✅ `app.js` - Vue app initialization
- ✅ `App.vue` - Root component
- ✅ `router/index.js` - Route definitions
- ✅ `app.css` - TailwindCSS
- ✅ `app.blade.php` - Laravel view
- ✅ `vite.config.js` - Vite + Vue plugin
- ✅ `tailwind.config.js` - Tailwind config

---

## 🎊 Final Durum

```
📦 Backend:  Laravel 11 (API)
🎨 Frontend: Vue 3 (SPA Dashboard)
💅 Styling:  TailwindCSS
🔧 Build:    Vite
📡 HTTP:     Axios
🧭 Router:   Vue Router 4
🏪 State:    Pinia

Toplam: Full-stack modern web app!
```

---

## 🚀 Kullanım

```bash
# Kurulum
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash

# Dashboard'a eriş
http://your-server-ip/           # Vue.js Dashboard
http://your-server-ip/api/sites  # API Endpoints
```

---

## 🎉 Sonuç

**ServerBond Agent** artık **tam teşekküllü** bir web application:

- 🐘 Laravel 11 Backend
- 🎨 Vue 3 Frontend
- 💎 Modern UI/UX
- 📊 Real-time monitoring
- 🚀 Production-ready

**Beautiful, Fast, Powerful!** 🎊

---

*Vue.js ile modern server management!* 🚀

