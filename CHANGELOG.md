# Changelog

Tüm önemli değişiklikler bu dosyada belgelenecektir.

## [1.0.0] - 2025-10-20

### Eklenenler
- **Multi-Site Yönetimi**: Sınırsız sayıda site oluşturma ve yönetme
- **Multi PHP Version Desteği**: PHP 8.1, 8.2, 8.3 desteği
- **PHP-FPM Pool İzolasyonu**: Her site için özel PHP-FPM pool
- **Site Türleri**: Laravel, PHP, Static, Python, Node.js desteği
- **Git Entegrasyonu**: Repository'lerden otomatik çekme ve deploy
- **Otomatik Nginx Konfigürasyonu**: Her site türü için optimize edilmiş konfigürasyon
- **MySQL Yönetimi**: Veritabanı ve kullanıcı oluşturma/yönetme
- **Redis Entegrasyonu**: Cache ve session yönetimi
- **Deploy Sistemi**: Arka planda çalışan deploy sistemi
- **SSL/Let's Encrypt**: Otomatik SSL sertifika yönetimi
- **Worker/Queue Yönetimi**: Supervisor ile Laravel queue worker'ları
- **Cron Job Yönetimi**: Laravel scheduler ve özel cron job'lar
- **RESTful API**: FastAPI tabanlı modern API
- **Sistem Monitoring**: CPU, RAM, Disk, Network izleme
- **Servis Yönetimi**: Nginx, MySQL, Redis, PHP-FPM durumu ve yönetimi

### API Endpoints
- `/api/sites/` - Site yönetimi
- `/api/deploy/` - Deploy işlemleri
- `/api/database/` - Veritabanı yönetimi
- `/api/php/` - PHP version yönetimi
- `/api/system/` - Sistem bilgileri ve istatistikleri
- `/health` - Sağlık kontrolü

### Güvenlik
- MySQL root şifresi otomatik oluşturulur
- API secret key otomatik oluşturulur
- Firewall (UFW) otomatik yapılandırılır
- PHP-FPM pool izolasyonu ve güvenlik ayarları
- SSL/TLS desteği

### Performans
- OPcache optimizasyonu
- Nginx gzip compression
- PHP-FPM pool optimizasyonu
- Redis cache desteği

### Dokümantasyon
- Detaylı README.md
- API dokümantasyonu (Swagger/ReDoc)
- Örnek kullanım scriptleri
- Kurulum kılavuzu

## Planlanan Özellikler

### [1.1.0] - Yakında
- [ ] Firewall kuralları yönetimi (UFW)
- [ ] SSH key yönetimi
- [ ] Backup otomasyonu
- [ ] Site klonlama
- [ ] Staging ortamları
- [ ] Multi-user desteği ve rol yönetimi
- [ ] Webhook entegrasyonu
- [ ] Slack/Discord bildirimler

### [1.2.0] - Gelecek
- [ ] PostgreSQL desteği
- [ ] MongoDB desteği
- [ ] Docker container desteği
- [ ] Load balancer yönetimi
- [ ] CDN entegrasyonu
- [ ] S3 backup entegrasyonu
- [ ] Git submodule desteği
- [ ] Custom deployment scripts

### [2.0.0] - Uzak Gelecek
- [ ] Web UI (Dashboard)
- [ ] Mobile app
- [ ] Multi-server yönetimi
- [ ] Cluster yönetimi
- [ ] Auto-scaling
- [ ] CI/CD pipeline entegrasyonu
- [ ] Monitoring ve alerting sistemi
- [ ] Log aggregation ve analiz

