#!/bin/bash

# Laravel Site Oluşturma Örneği

API_URL="http://localhost:8000"

echo "🚀 Laravel Site Oluşturuluyor..."

# Site oluştur
RESPONSE=$(curl -s -X POST "$API_URL/api/sites/" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "laravel-demo.test",
    "site_type": "laravel",
    "git_repo": "https://github.com/laravel/laravel.git",
    "git_branch": "10.x",
    "php_version": "8.2",
    "ssl_enabled": false,
    "env_vars": {
      "APP_ENV": "production",
      "APP_DEBUG": "false",
      "APP_KEY": "base64:your-app-key-here"
    }
  }')

echo "$RESPONSE" | jq '.'

SITE_ID=$(echo "$RESPONSE" | jq -r '.site.id')

if [ "$SITE_ID" != "null" ]; then
    echo "✓ Site oluşturuldu: $SITE_ID"
    
    # Database oluştur
    echo ""
    echo "📊 Veritabanı oluşturuluyor..."
    
    DB_RESPONSE=$(curl -s -X POST "$API_URL/api/database/" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "laravel_demo",
        "user": "laravel_user",
        "password": "SecurePassword123!",
        "host": "localhost"
      }')
    
    echo "$DB_RESPONSE" | jq '.'
    
    echo ""
    echo "✓ Kurulum tamamlandı!"
    echo ""
    echo "Siteye erişmek için /etc/hosts dosyanıza şunu ekleyin:"
    echo "127.0.0.1  laravel-demo.test"
    echo ""
    echo "Tarayıcınızda http://laravel-demo.test adresine gidin"
else
    echo "✗ Site oluşturulamadı"
fi

