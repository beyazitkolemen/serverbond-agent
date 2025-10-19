# ServerBond Agent Dockerfile
FROM python:3.11-slim

# Metadata
LABEL maintainer="ServerBond"
LABEL description="Docker container yönetimi için Python agent"

# Çalışma dizini
WORKDIR /app

# Sistem paketlerini güncelle ve gerekli paketleri kur
RUN apt-get update && apt-get install -y \
    curl \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Python bağımlılıklarını kopyala ve yükle
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama kodlarını kopyala
COPY app/ ./app/

# .env dosyası için placeholder (runtime'da override edilecek)
ENV AGENT_TOKEN=change-me-in-production
ENV API_HOST=0.0.0.0
ENV API_PORT=8000
ENV LOG_LEVEL=INFO

# Port expose et
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/system/health || exit 1

# Uygulamayı başlat
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

