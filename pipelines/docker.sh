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
    local default_shared=("file:.env" "file:docker-compose.yml" "file:docker-compose.override.yml")
    
    # Paylaşılan kaynakları kur
    setup_shared_resources "${release_dir}" "${SHARED_DIR}" "${default_shared[@]}" "${CUSTOM_SHARED[@]}"
    
    # Docker build
    log_info "Docker build çalıştırılıyor..."
    local docker_script="${DEPLOY_DIR}/../docker/build_image.sh"
    if [[ ! -x "${docker_script}" ]]; then
        log_error "Docker build scripti bulunamadı."
        return 1
    fi
    
    # Docker Compose dosyası kontrolü
    if [[ -f "${release_dir}/docker-compose.yml" ]]; then
        log_info "Docker Compose ile build yapılıyor..."
        (
            cd "${release_dir}"
            if ! docker-compose build --no-cache; then
                log_error "Docker Compose build başarısız"
                return 1
            fi
        )
    else
        log_info "Dockerfile ile build yapılıyor..."
        if ! "${docker_script}" --path "${release_dir}"; then
            log_error "Docker build başarısız"
            return 1
        fi
    fi
    log_success "Docker build tamamlandı"
    
    # Docker deploy
    log_info "Docker deploy çalıştırılıyor..."
    if [[ -f "${release_dir}/docker-compose.yml" ]]; then
        log_info "Docker Compose ile deploy yapılıyor..."
        (
            cd "${release_dir}"
            docker-compose down
            if ! docker-compose up -d; then
                log_error "Docker Compose deploy başarısız"
                return 1
            fi
        )
    else
        log_warning "Docker Compose dosyası bulunamadı, manuel deploy gerekli."
    fi
    log_success "Docker deploy tamamlandı"
    
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