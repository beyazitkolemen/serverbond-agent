#!/bin/bash

# ServerBond Agent API Test Script

echo "🧪 ServerBond Agent API Test"
echo ""

cd api

# Laravel serve başlat (IPv4)
echo "▸ Starting Laravel serve on 127.0.0.1:8000..."
php artisan serve --host=127.0.0.1 --port=8000 > /dev/null 2>&1 &
SERVE_PID=$!

# Sunucunun başlamasını bekle
sleep 5

echo "▸ Testing API endpoints..."
echo ""

# Test endpoints
echo "1. ❤️  Health Check:"
curl -s http://127.0.0.1:8000/api/health | jq . 2>/dev/null || curl -s http://127.0.0.1:8000/api/health
echo ""

echo "2. 💻 System Info:"
curl -s http://127.0.0.1:8000/api/system/info | jq . 2>/dev/null || curl -s http://127.0.0.1:8000/api/system/info
echo ""

echo "3. 📊 System Stats:"
curl -s http://127.0.0.1:8000/api/system/stats | jq . 2>/dev/null || curl -s http://127.0.0.1:8000/api/system/stats
echo ""

echo "4. 🌐 Sites:"
curl -s http://127.0.0.1:8000/api/sites | jq . 2>/dev/null || curl -s http://127.0.0.1:8000/api/sites
echo ""

echo "5. 🐘 PHP Versions:"
curl -s http://127.0.0.1:8000/api/php/versions | jq . 2>/dev/null || curl -s http://127.0.0.1:8000/api/php/versions
echo ""

# Serve'i durdur
kill $SERVE_PID 2>/dev/null
wait $SERVE_PID 2>/dev/null

echo ""
echo "✅ Test tamamlandı!"
echo ""
echo "📝 Not: Production'da Nginx üzerinden http://your-ip/ adresinde çalışacak"
