#!/bin/bash

# SSL ile Laravel Site Oluşturma Örneği

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Kullanım: $0 <domain> <email>"
    echo "Örnek: $0 example.com admin@example.com"
    exit 1
fi

DOMAIN="$1"
EMAIL="$2"
API_URL="http://localhost:8000"

echo "🚀 SSL ile Laravel Site Oluşturuluyor..."
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""

# Site oluştur
echo "1. Site oluşturuluyor..."
SITE_RESPONSE=$(curl -s -X POST "$API_URL/api/sites/" \
  -H "Content-Type: application/json" \
  -d "{
    \"domain\": \"$DOMAIN\",
    \"site_type\": \"laravel\",
    \"git_repo\": \"https://github.com/laravel/laravel.git\",
    \"git_branch\": \"10.x\",
    \"php_version\": \"8.2\",
    \"ssl_enabled\": false,
    \"env_vars\": {
      \"APP_ENV\": \"production\",
      \"APP_DEBUG\": \"false\"
    }
  }")

echo "$SITE_RESPONSE" | jq '.'

SITE_ID=$(echo "$SITE_RESPONSE" | jq -r '.site.id')

if [ "$SITE_ID" = "null" ]; then
    echo "✗ Site oluşturulamadı"
    exit 1
fi

echo "✓ Site oluşturuldu: $SITE_ID"
echo ""

# Database oluştur
echo "2. Veritabanı oluşturuluyor..."
DB_NAME="${SITE_ID//-/_}_db"
DB_USER="${SITE_ID//-/_}_user"
DB_PASS=$(openssl rand -base64 16)

DB_RESPONSE=$(curl -s -X POST "$API_URL/api/database/" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$DB_NAME\",
    \"user\": \"$DB_USER\",
    \"password\": \"$DB_PASS\",
    \"host\": \"localhost\"
  }")

echo "$DB_RESPONSE" | jq '.'
echo "✓ Veritabanı oluşturuldu"
echo ""

# SSL sertifikası al (Bu kısım API'ye eklenmeli)
echo "3. SSL sertifikası alınıyor..."
echo "Not: SSL endpoint'i henüz eklenmedi. Manuel olarak ekleyebilirsiniz:"
echo ""
echo "sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL"
echo ""

# Laravel scheduler kurulumu
echo "4. Laravel scheduler kuruluyor..."
echo "Not: Cron endpoint'i henüz eklenmedi. Manuel olarak ekleyebilirsiniz:"
echo ""
echo "curl -X POST $API_URL/api/cron/ -H 'Content-Type: application/json' -d '{\"site_id\": \"$SITE_ID\", \"type\": \"laravel_scheduler\"}'"
echo ""

echo "✓ Kurulum tamamlandı!"
echo ""
echo "📝 Bağlantı Bilgileri:"
echo "-------------------"
echo "Domain: https://$DOMAIN"
echo "Site ID: $SITE_ID"
echo "Database: $DB_NAME"
echo "DB User: $DB_USER"
echo "DB Password: $DB_PASS"
echo ""
echo "🔧 Sonraki Adımlar:"
echo "1. DNS A kaydınızı sunucu IP'nize yönlendirin"
echo "2. SSL sertifikası için yukarıdaki komutu çalıştırın"
echo "3. .env dosyasını düzenleyin"
echo "4. Deploy yapın: curl -X POST $API_URL/api/deploy/ -d '{\"site_id\": \"$SITE_ID\", \"run_migrations\": true}'"

