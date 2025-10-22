# .env Yönetimi Örnekleri

Bu dosya, yeni .env yönetim sisteminin nasıl kullanılacağını gösterir.

## Temel Kullanım

### 1. .env.example'dan Otomatik .env Oluşturma

Laravel projelerinde `.env.example` dosyası varsa, otomatik olarak `.env` dosyası oluşturulur:

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch main
```

### 2. Parametre ile .env Düzenleme

Tek tek parametreler ekleyerek .env dosyasını düzenleyin:

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch main \
  --env-param "APP_NAME=MyApp" \
  --env-param "APP_ENV=production" \
  --env-param "DB_HOST=db.example.com" \
  --env-param "DB_DATABASE=myapp_prod" \
  --env-param "DB_USERNAME=prod_user" \
  --env-param "DB_PASSWORD=secret123"
```

### 3. Toplu .env İçeriği ile Düzenleme

Tam .env içeriğini belirleyin:

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch main \
  --env-content "APP_NAME=MyApp
APP_ENV=production
APP_KEY=base64:abcdefghijklmnopqrstuvwxyz1234567890=
APP_DEBUG=false
APP_URL=https://myapp.example.com

DB_CONNECTION=mysql
DB_HOST=db.example.com
DB_PORT=3306
DB_DATABASE=myapp_prod
DB_USERNAME=prod_user
DB_PASSWORD=super_secret_password

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

REDIS_HOST=redis.example.com
REDIS_PASSWORD=redis_secret
REDIS_PORT=6379"
```

## Gelişmiş Kullanım

### 4. Parametre ve İçerik Kombinasyonu

Önce .env.example'dan temel yapı oluşturulur, sonra parametreler uygulanır, en son toplu içerik uygulanır:

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch main \
  --env-param "APP_NAME=MyApp" \
  --env-param "APP_ENV=production" \
  --env-content "DB_HOST=production-db.example.com
DB_DATABASE=myapp_production
DB_USERNAME=prod_user
DB_PASSWORD=super_secret_password"
```

### 5. Farklı Ortamlar için Konfigürasyon

#### Staging Ortamı
```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch staging \
  --env-param "APP_ENV=staging" \
  --env-param "APP_DEBUG=true" \
  --env-param "DB_HOST=staging-db.example.com" \
  --env-param "DB_DATABASE=myapp_staging"
```

#### Production Ortamı
```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch production \
  --env-param "APP_ENV=production" \
  --env-param "APP_DEBUG=false" \
  --env-param "DB_HOST=production-db.example.com" \
  --env-param "DB_DATABASE=myapp_production"
```

### 6. Güvenlik ve Gizli Bilgiler

Gizli bilgileri güvenli bir şekilde yönetin:

```bash
# Sadece gerekli parametreleri belirtin
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch main \
  --env-param "APP_KEY=base64:$(openssl rand -base64 32)=" \
  --env-param "DB_PASSWORD=$(openssl rand -base64 32)" \
  --env-param "REDIS_PASSWORD=$(openssl rand -base64 32)"
```

### 7. Docker ile Kullanım

Docker konteynerleri için .env yönetimi:

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch main \
  --env-param "APP_ENV=production" \
  --env-param "DB_HOST=mysql" \
  --env-param "REDIS_HOST=redis" \
  --env-param "CACHE_DRIVER=redis" \
  --env-param "SESSION_DRIVER=redis"
```

## Özellikler

### ✅ Desteklenen Özellikler

- **Otomatik .env.example kopyalama**: Projede `.env.example` varsa otomatik olarak `.env` oluşturulur
- **Parametre bazlı düzenleme**: `--env-param KEY=VALUE` ile tek tek değerler ayarlanabilir
- **Toplu içerik düzenleme**: `--env-content` ile tam .env içeriği belirlenebilir
- **Mevcut değer güncelleme**: Var olan anahtarlar güncellenir, yeni anahtarlar eklenir
- **Güvenlik**: .env dosyası 600 izinleri ile oluşturulur
- **Yedekleme**: Toplu içerik uygulanmadan önce .env.backup oluşturulur

### ❌ Kaldırılan Özellikler

- **Shared .env yapısı**: .env dosyası artık shared dizinde saklanmaz
- **--env parametresi**: Eski `--env SRC:TARGET` parametresi kaldırıldı
- **Manuel .env kopyalama**: .env dosyaları artık manuel olarak kopyalanmaz

## Migration Rehberi

### Eski Kullanımdan Yeni Kullanıma Geçiş

#### Eski Kullanım:
```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/app.git \
  --env /secrets/production.env:.env \
  --shared "file:.env,dir:storage"
```

#### Yeni Kullanım:
```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/app.git \
  --env-param "APP_ENV=production" \
  --env-param "DB_HOST=db.example.com" \
  --shared "dir:storage"
```

### Adım Adım Migration

1. **Mevcut .env dosyasını yedekleyin**:
   ```bash
   cp /var/www/current/.env /backup/.env.backup
   ```

2. **Yeni pipeline'ı test edin**:
   ```bash
   sudo ./pipelines/laravel.sh \
     --repo git@github.com:example/app.git \
     --branch test \
     --no-activate \
     --env-param "APP_ENV=production"
   ```

3. **Production'a uygulayın**:
   ```bash
   sudo ./pipelines/laravel.sh \
     --repo git@github.com:example/app.git \
     --branch main \
     --env-param "APP_ENV=production"
   ```

## Sorun Giderme

### .env.example Bulunamadı
```
⚠ .env.example dosyası bulunamadı
```
**Çözüm**: Projede `.env.example` dosyası oluşturun veya `--env-content` ile tam içerik belirleyin.

### Parametre Uygulanamadı
```
⚠ Geçersiz .env parametresi: INVALID_PARAM
```
**Çözüm**: Parametre formatını `KEY=VALUE` şeklinde kontrol edin.

### İzin Hatası
```
Permission denied: .env
```
**Çözüm**: Pipeline'ı `sudo` ile çalıştırdığınızdan emin olun.

## En İyi Uygulamalar

1. **Güvenlik**: Gizli bilgileri parametre olarak geçmeyin, bunun yerine güvenli bir şekilde saklayın
2. **Yedekleme**: Önemli .env dosyalarını düzenli olarak yedekleyin
3. **Test**: Değişiklikleri önce test ortamında deneyin
4. **Dokümantasyon**: Kullanılan parametreleri dokümante edin
5. **Versiyonlama**: .env.example dosyasını versiyon kontrolünde tutun