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

### Laravel Pipeline Özellikleri
- `--setup-nginx`: Laravel için Nginx site otomatik kurulumu
- `--setup-mysql`: Laravel için MySQL veritabanı otomatik kurulumu
- Otomatik .env dosyası güncelleme
- Laravel template ile Nginx yapılandırması

### WordPress Pipeline Özellikleri
- `--setup-nginx`: WordPress için Nginx site otomatik kurulumu
- `--setup-mysql`: WordPress için MySQL veritabanı otomatik kurulumu
- Otomatik wp-config.php güncelleme
- PHP template ile Nginx yapılandırması

### Next.js Pipeline Özellikleri
- `--setup-nginx`: Next.js için Nginx site otomatik kurulumu
- Static template ile Nginx yapılandırması
- Otomatik build dizini tespiti

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
```

### Next.js Projesi
```bash
# Next.js deployment
./pipelines/next.sh --repo https://github.com/user/nextjs-app.git \
  --setup-nginx \
  --nginx-domain myapp.com \
  --nginx-ssl-email admin@myapp.com
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