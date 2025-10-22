#!/usr/bin/env bash
set -euo pipefail

# Docker özel pipeline fonksiyonları
# Bu dosya Docker projeleri için özel deployment adımlarını içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# Docker özel değişkenler
# Docker için özel değişken yok, sadece ortak seçenekler kullanılır

# Docker özel kullanım bilgisi
print_docker_usage() {
    cat <<'USAGE'
Docker Pipeline Kullanımı:
  pipelines/docker.sh --repo <GIT_URL> [seçenekler]

Docker Özel Seçenekleri:
  (Docker için özel seçenek yok, sadece ortak seçenekler kullanılır)

Ortak seçenekler için --help ortak seçenekleri gösterir.
USAGE
}

# Docker özel argüman parsing
parse_docker_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                print_docker_usage
                exit 0
                ;;
            *)
                # Bilinmeyen seçenek - ortak pipeline'a gönder
                return 1
                ;;
        esac
    done
    return 0
}

# Docker özel adımları
run_docker_steps() {
    local release_dir="$1"
    
    # Varsayılan değerleri ayarla
    local default_shared=("file:.env" "file:docker-compose.yml" "file:docker-compose.override.yml" "file:docker-compose.prod.yml" "file:Dockerfile" "file:.dockerignore")
    
    # Paylaşılan kaynakları kur
    setup_shared_resources "${release_dir}" "${SHARED_DIR}" "${default_shared[@]}" "${CUSTOM_SHARED[@]}"
    
    # Docker Compose komutunu belirle
    local compose_bin=""
    if command -v docker-compose >/dev/null 2>&1; then
        compose_bin="docker-compose"
        log_info "docker-compose kullanılıyor"
    elif docker compose version >/dev/null 2>&1; then
        compose_bin="docker compose"
        log_info "docker compose kullanılıyor"
    else
        log_error "docker-compose veya docker compose komutu bulunamadı."
        return 1
    fi
    
    # Docker Compose dosyası kontrolü
    if [[ -f "${release_dir}/docker-compose.yml" ]]; then
        log_info "Docker Compose ile deployment yapılıyor..."
        
        # Environment dosyası kontrolü
        local env_file=""
        if [[ -f "${release_dir}/.env.production" ]]; then
            env_file=".env.production"
        elif [[ -f "${release_dir}/.env" ]]; then
            env_file=".env"
        fi
        
        # Compose argümanlarını hazırla
        local compose_args=()
        [[ -n "${env_file}" ]] && compose_args+=(--env-file "${env_file}")
        
        # Önceki servisleri durdur
        log_info "Önceki servisler durduruluyor..."
        (
            cd "${release_dir}"
            ${compose_bin} "${compose_args[@]}" down --remove-orphans --timeout 30
        ) || log_warning "Önceki servisler durdurulamadı"
        
        # Build işlemi
        log_info "Docker Compose build çalıştırılıyor..."
        if ! (
            cd "${release_dir}"
            ${compose_bin} "${compose_args[@]}" build --no-cache --parallel
        ); then
            log_error "Docker Compose build başarısız"
            return 1
        fi
        
        # Servisleri başlat
        log_info "Docker Compose servisleri başlatılıyor..."
        if ! (
            cd "${release_dir}"
            ${compose_bin} "${compose_args[@]}" up -d --remove-orphans
        ); then
            log_error "Docker Compose deploy başarısız"
            return 1
        fi
        
        # Health check
        log_info "Container health check yapılıyor..."
        local health_script="${DEPLOY_DIR}/../docker/health_check.sh"
        if [[ -x "${health_script}" ]]; then
            # Tüm çalışan container'ları kontrol et
            local containers
            containers=$(docker ps --format "{{.Names}}" --filter "label=com.docker.compose.project")
            
            for container in ${containers}; do
                if ! "${health_script}" --name "${container}" --timeout 60 --verbose; then
                    log_warning "Container health check başarısız: ${container}"
                fi
            done
        fi
        
        # Servis durumunu göster
        log_info "Çalışan servisler:"
        (
            cd "${release_dir}"
            ${compose_bin} "${compose_args[@]}" ps
        )
        
    else
        log_info "Dockerfile ile build yapılıyor..."
        local docker_script="${DEPLOY_DIR}/../docker/build_image.sh"
        if [[ ! -x "${docker_script}" ]]; then
            log_error "Docker build scripti bulunamadı."
            return 1
        fi
        
        # Image tag oluştur
        local image_tag="${PROJECT_NAME:-app}:${RELEASE_ID:-latest}"
        
        if ! "${docker_script}" --tag "${image_tag}" --path "${release_dir}"; then
            log_error "Docker build başarısız"
            return 1
        fi
        
        log_warning "Docker Compose dosyası bulunamadı, manuel deploy gerekli."
        log_info "Build edilen image: ${image_tag}"
    fi
    
    # Cleanup - eski image'ları temizle
    log_info "Eski Docker image'ları temizleniyor..."
    docker image prune -f || log_warning "Image cleanup başarısız"
    
    log_success "Docker deployment tamamlandı"
    
    return 0
}

# Docker callback fonksiyonu
docker_callback() {
    local action="$1"
    shift
    
    case "${action}" in
        "parse_args")
            parse_docker_args "$@"
            ;;
        "run_steps")
            run_docker_steps "$@"
            ;;
        *)
            log_error "Bilinmeyen Docker callback action: ${action}"
            return 1
            ;;
    esac
}

# Ana Docker pipeline
main() {
    # Docker özel argümanları parse et
    local docker_args=()
    local common_args=()
    local in_common=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo|--branch|--depth|--keep|--base-dir|--releases-dir|--shared-dir|--current-link|--shared|--env|--owner|--group|--post-cmd|--no-activate|--submodules|--rollback-on-failure|--health-check|--health-timeout|--webhook|--notification)
                in_common=true
                ;;
        esac
        
        if [[ "${in_common}" == true ]]; then
            common_args+=("$1")
        else
            docker_args+=("$1")
        fi
        shift
    done
    
    # Docker özel argümanları parse et
    if ! parse_docker_args "${docker_args[@]}"; then
        log_error "Docker argüman parsing başarısız"
        exit 1
    fi
    
    # Ortak pipeline'ı çağır
    source "${PIPELINE_SCRIPT}"
    run_common_deployment "docker" "docker_callback" "${common_args[@]}"
}

# Script çalıştırıldığında main fonksiyonunu çağır
main "$@"