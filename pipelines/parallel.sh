#!/usr/bin/env bash
set -euo pipefail

# Paralel deployment scripti
# Birden fazla projeyi aynı anda deploy etmek için kullanılır

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# Paralel deployment konfigürasyonu
# Format: project_type:repo_url:branch:additional_args
# Örnek: laravel:git@github.com:user/project.git:main:--env /secrets/.env
DEPLOYMENTS=()

# Maksimum paralel işlem sayısı
MAX_PARALLEL=3

# Log dosyası
LOG_DIR="/var/log/serverbond-agent"
mkdir -p "${LOG_DIR}"

print_usage() {
    cat <<'USAGE'
Kullanım: pipelines/parallel.sh [seçenekler]

Paralel deployment için konfigürasyon dosyası veya komut satırı parametreleri kullanın.

Seçenekler:
  --config FILE           Deployment konfigürasyon dosyası
  --max-parallel N        Maksimum paralel işlem sayısı (varsayılan: 3)
  --deploy TYPE:REPO:BRANCH:ARGS  Tek deployment ekle
  --help, -h              Bu yardımı göster

Konfigürasyon dosyası formatı (her satır bir deployment):
laravel:git@github.com:user/laravel-app.git:main:--env /secrets/.env
react:git@github.com:user/react-app.git:develop:--run-tests
docker:git@github.com:user/docker-app.git:main:--health-check https://app.example.com/health

Örnek kullanım:
  sudo ./pipelines/parallel.sh --config deployments.conf
  sudo ./pipelines/parallel.sh --deploy "laravel:git@github.com:user/app.git:main:--env /secrets/.env"
USAGE
}

load_config() {
    local config_file="$1"
    if [[ ! -f "${config_file}" ]]; then
        echo "Konfigürasyon dosyası bulunamadı: ${config_file}" >&2
        exit 1
    fi
    
    while IFS= read -r line; do
        # Boş satırları ve yorumları atla
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        
        DEPLOYMENTS+=("${line}")
    done < "${config_file}"
}

run_deployment() {
    local deployment="$1"
    local log_file="${LOG_DIR}/deployment-$(date +%Y%m%d%H%M%S)-$$.log"
    
    IFS=':' read -r type repo branch args <<< "${deployment}"
    
    echo "Deployment başlatılıyor: ${type} - ${repo}" | tee -a "${log_file}"
    
    if "${PIPELINE_SCRIPT}" --type "${type}" --repo "${repo}" --branch "${branch}" ${args} >> "${log_file}" 2>&1; then
        echo "Deployment başarılı: ${type} - ${repo}" | tee -a "${log_file}"
        return 0
    else
        echo "Deployment başarısız: ${type} - ${repo}" | tee -a "${log_file}"
        return 1
    fi
}

run_parallel_deployments() {
    local pids=()
    local results=()
    local deployment_index=0
    local running=0
    local completed=0
    local failed=0
    
    echo "Toplam ${#DEPLOYMENTS[@]} deployment başlatılıyor..."
    
    while [[ ${deployment_index} -lt ${#DEPLOYMENTS[@]} || ${running} -gt 0 ]]; do
        # Yeni deployment'ları başlat
        while [[ ${running} -lt ${MAX_PARALLEL} && ${deployment_index} -lt ${#DEPLOYMENTS[@]} ]]; do
            local deployment="${DEPLOYMENTS[${deployment_index}]}"
            run_deployment "${deployment}" &
            local pid=$!
            pids+=("${pid}")
            results+=("${deployment}")
            ((deployment_index++))
            ((running++))
            echo "Deployment başlatıldı (PID: ${pid}): ${deployment}"
        done
        
        # Tamamlanan işlemleri kontrol et
        local new_pids=()
        local new_results=()
        for i in "${!pids[@]}"; do
            local pid="${pids[i]}"
            local result="${results[i]}"
            
            if kill -0 "${pid}" 2>/dev/null; then
                # Hala çalışıyor
                new_pids+=("${pid}")
                new_results+=("${result}")
            else
                # Tamamlandı
                wait "${pid}"
                local exit_code=$?
                if [[ ${exit_code} -eq 0 ]]; then
                    ((completed++))
                    echo "Deployment tamamlandı: ${result}"
                else
                    ((failed++))
                    echo "Deployment başarısız: ${result}"
                fi
                ((running--))
            fi
        done
        
        pids=("${new_pids[@]}")
        results=("${new_results[@]}")
        
        # Kısa bir süre bekle
        sleep 1
    done
    
    echo "Tüm deployment'lar tamamlandı."
    echo "Başarılı: ${completed}, Başarısız: ${failed}"
    
    if [[ ${failed} -gt 0 ]]; then
        exit 1
    fi
}

# Ana script
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            load_config "${2:-}"
            shift 2
            ;;
        --max-parallel)
            MAX_PARALLEL="${2:-3}"
            shift 2
            ;;
        --deploy)
            DEPLOYMENTS+=("${2:-}")
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "Bilinmeyen seçenek: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

if [[ ${#DEPLOYMENTS[@]} -eq 0 ]]; then
    echo "Hiç deployment tanımlanmamış." >&2
    print_usage
    exit 1
fi

run_parallel_deployments