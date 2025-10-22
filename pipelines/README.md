# Pipeline Scripts - Nginx ve MySQL Otomatik Kurulum

Bu pipeline scriptleri artık nginx ve mysql otomatik kurulum özelliklerini içermektedir.

## Özellikler

### Ortak Özellikler (Tüm Pipeline'lar)
- `--auto-install-nginx`: Nginx'i otomatik olarak kur ve yapılandır
- `--auto-install-mysql`: MySQL'i otomatik olarak kur ve yapılandır
- `--nginx-domain DOMAIN`: Nginx site domain adı
- `--nginx-template TYPE`: Nginx template türü (default|laravel|php|static)
- `--nginx-ssl-email EMAIL`: SSL sertifikası için email adresi
- `--mysql-database DB`: MySQL veritabanı adı
- `--mysql-user USER`: MySQL kullanıcı adı
- `--mysql-password PASS`: MySQL kullanıcı şifresi
- `--mysql-host HOST`: MySQL host adresi (varsayılan: localhost)

### Güncelleme Sistemi Özellikleri
- `--auto-update`: Otomatik güncelleme sistemi aktif et
- `--update-before-deploy`: Deployment öncesi güncelleme yap
- `--update-after-deploy`: Deployment sonrası güncelleme yap
- `--update-cmd "komut"`: Güncelleme komutu (birden fazla kullanılabilir)
- `--pre-update-cmd "komut"`: Güncelleme öncesi komut (birden fazla kullanılabilir)
- `--post-update-cmd "komut"`: Güncelleme sonrası komut (birden fazla kullanılabilir)
- `--update-rollback`: Güncelleme başarısız olursa rollback yap
- `--update-webhook URL`: Güncelleme bildirim webhook URL'i
- `--update-notification TYPE`: Güncelleme bildirim türü (slack|discord|email)

### Laravel Pipeline Özellikleri
- `--setup-nginx`: Laravel için Nginx site otomatik kurulumu
- `--setup-mysql`: Laravel için MySQL veritabanı otomatik kurulumu
- Otomatik .env dosyası güncelleme
- Laravel template ile Nginx yapılandırması
- `--skip-update-composer`: Güncelleme sırasında composer update'i atla
- `--skip-update-npm`: Güncelleme sırasında npm update'i atla
- `--skip-update-artisan`: Güncelleme sırasında artisan komutlarını atla
- `--skip-update-cache`: Güncelleme sırasında cache güncellemelerini atla
- `--laravel-update-cmd "komut"`: Laravel özel güncelleme komutu
- `--laravel-pre-update-cmd "komut"`: Laravel güncelleme öncesi komut
- `--laravel-post-update-cmd "komut"`: Laravel güncelleme sonrası komut

### WordPress Pipeline Özellikleri
- `--setup-nginx`: WordPress için Nginx site otomatik kurulumu
- `--setup-mysql`: WordPress için MySQL veritabanı otomatik kurulumu
- Otomatik wp-config.php güncelleme
- PHP template ile Nginx yapılandırması
- `--skip-update-plugins`: Güncelleme sırasında plugin güncellemelerini atla
- `--skip-update-themes`: Güncelleme sırasında tema güncellemelerini atla
- `--skip-update-core`: Güncelleme sırasında WordPress core güncellemelerini atla
- `--wp-update-cmd "komut"`: WordPress özel güncelleme komutu
- `--wp-pre-update-cmd "komut"`: WordPress güncelleme öncesi komut
- `--wp-post-update-cmd "komut"`: WordPress güncelleme sonrası komut

### Next.js Pipeline Özellikleri
- `--setup-nginx`: Next.js için Nginx site otomatik kurulumu
- Static template ile Nginx yapılandırması
- Otomatik build dizini tespiti
- `--skip-update-npm`: Güncelleme sırasında npm update'i atla
- `--next-update-cmd "komut"`: Next.js özel güncelleme komutu
- `--next-pre-update-cmd "komut"`: Next.js güncelleme öncesi komut
- `--next-post-update-cmd "komut"`: Next.js güncelleme sonrası komut

## Kullanım Örnekleri

### Laravel Projesi
```bash
# Temel Laravel deployment
./pipelines/laravel.sh --repo https://github.com/user/laravel-app.git \
  --setup-nginx --setup-mysql \
  --nginx-domain myapp.com \
  --nginx-ssl-email admin@myapp.com \
  --mysql-database myapp_db \
  --mysql-user myapp_user \
  --mysql-password secure_password

# Güncelleme sistemi ile Laravel deployment
./pipelines/laravel.sh --repo https://github.com/user/laravel-app.git \
  --setup-nginx --setup-mysql \
  --auto-update --update-before-deploy --update-after-deploy \
  --nginx-domain myapp.com \
  --nginx-ssl-email admin@myapp.com \
  --mysql-database myapp_db \
  --mysql-user myapp_user \
  --mysql-password secure_password \
  --laravel-update-cmd "php artisan config:cache" \
  --laravel-pre-update-cmd "composer dump-autoload" \
  --laravel-post-update-cmd "php artisan queue:restart"

# Sadece Nginx kurulumu
./pipelines/laravel.sh --repo https://github.com/user/laravel-app.git \
  --setup-nginx \
  --nginx-domain myapp.com \
  --nginx-template laravel
```

### WordPress Projesi
```bash
# Tam WordPress deployment
./pipelines/wordpress.sh --repo https://github.com/user/wordpress-site.git \
  --setup-nginx --setup-mysql \
  --nginx-domain mysite.com \
  --nginx-ssl-email admin@mysite.com \
  --mysql-database wp_db \
  --mysql-user wp_user \
  --mysql-password wp_password

# Güncelleme sistemi ile WordPress deployment
./pipelines/wordpress.sh --repo https://github.com/user/wordpress-site.git \
  --setup-nginx --setup-mysql \
  --auto-update --update-after-deploy \
  --nginx-domain mysite.com \
  --nginx-ssl-email admin@mysite.com \
  --mysql-database wp_db \
  --mysql-user wp_user \
  --mysql-password wp_password \
  --wp-update-cmd "wp core update-db --allow-root" \
  --wp-pre-update-cmd "wp maintenance-mode activate --allow-root" \
  --wp-post-update-cmd "wp maintenance-mode deactivate --allow-root"
```

### Next.js Projesi
```bash
# Next.js deployment
./pipelines/next.sh --repo https://github.com/user/nextjs-app.git \
  --setup-nginx \
  --nginx-domain myapp.com \
  --nginx-ssl-email admin@myapp.com

# Güncelleme sistemi ile Next.js deployment
./pipelines/next.sh --repo https://github.com/user/nextjs-app.git \
  --setup-nginx \
  --auto-update --update-before-deploy --update-after-deploy \
  --nginx-domain myapp.com \
  --nginx-ssl-email admin@myapp.com \
  --next-update-cmd "npm run build" \
  --next-pre-update-cmd "npm ci" \
  --next-post-update-cmd "npm run postbuild"
```

## Otomatik Kurulum Süreci

### Nginx Kurulumu
1. Nginx kurulu mu kontrol edilir
2. Kurulu değilse otomatik kurulum yapılır
3. Domain belirtilmişse site oluşturulur
4. Proje türüne uygun template kullanılır
5. SSL sertifikası istenirse otomatik kurulum yapılır

### MySQL Kurulumu
1. MySQL kurulu mu kontrol edilir
2. Kurulu değilse otomatik kurulum yapılır
3. Veritabanı oluşturulur
4. Kullanıcı oluşturulur ve yetkilendirilir
5. Proje yapılandırma dosyaları güncellenir

## Güncelleme Sistemi

### Ortak Güncelleme Süreci
1. Pre-update komutları çalıştırılır
2. Ana güncelleme komutları çalıştırılır (varsayılan: update.sh)
3. Post-update komutları çalıştırılır
4. Güncelleme bildirimi gönderilir

### Laravel Güncelleme Özellikleri
- Composer update (--skip-update-composer ile atlanabilir)
- NPM update (--skip-update-npm ile atlanabilir)
- Artisan cache komutları (--skip-update-artisan ile atlanabilir)
- Cache temizleme (--skip-update-cache ile atlanabilir)
- Özel güncelleme komutları

### WordPress Güncelleme Özellikleri
- WordPress core güncelleme (--skip-update-core ile atlanabilir)
- Plugin güncelleme (--skip-update-plugins ile atlanabilir)
- Tema güncelleme (--skip-update-themes ile atlanabilir)
- Özel güncelleme komutları

### Next.js Güncelleme Özellikleri
- NPM update (--skip-update-npm ile atlanabilir)
- Özel güncelleme komutları
- Build ve post-build komutları

## Yapılandırma Dosyaları

### Laravel (.env)
```env
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=myapp_db
DB_USERNAME=myapp_user
DB_PASSWORD=secure_password
```

### WordPress (wp-config.php)
```php
define('DB_NAME', 'wp_db');
define('DB_USER', 'wp_user');
define('DB_PASSWORD', 'wp_password');
define('DB_HOST', 'localhost:3306');
```

## Güvenlik

- MySQL şifreleri güvenli şekilde oluşturulur
- SSL sertifikaları otomatik olarak yapılandırılır
- Nginx güvenlik ayarları uygulanır
- Dosya izinleri otomatik olarak ayarlanır

## Hata Yönetimi

- Kurulum sırasında hata oluşursa detaylı log çıktısı verilir
- Rollback özelliği ile önceki sürüme dönüş mümkündür
- Health check ile deployment doğrulanır