#!/bin/bash

# Site Deploy Örneği

if [ -z "$1" ]; then
    echo "Kullanım: $0 <site-id>"
    echo "Örnek: $0 laravel-demo-test"
    exit 1
fi

SITE_ID="$1"
API_URL="http://localhost:8000"

echo "🚀 Site deploy ediliyor: $SITE_ID"

# Deploy başlat
RESPONSE=$(curl -s -X POST "$API_URL/api/deploy/" \
  -H "Content-Type: application/json" \
  -d "{
    \"site_id\": \"$SITE_ID\",
    \"git_branch\": \"main\",
    \"run_migrations\": true,
    \"clear_cache\": true,
    \"install_dependencies\": true
  }")

echo "$RESPONSE" | jq '.'

DEPLOY_ID=$(echo "$RESPONSE" | jq -r '.deploy_id')

if [ "$DEPLOY_ID" != "null" ]; then
    echo ""
    echo "✓ Deploy başlatıldı: $DEPLOY_ID"
    echo ""
    echo "Deploy durumunu kontrol etmek için:"
    echo "curl http://localhost:8000/api/deploy/$DEPLOY_ID | jq '.'"
    
    # 2 saniye bekle ve durumu kontrol et
    sleep 2
    
    echo ""
    echo "Mevcut durum:"
    curl -s "$API_URL/api/deploy/$DEPLOY_ID" | jq '{status, message, logs}'
else
    echo "✗ Deploy başlatılamadı"
fi

