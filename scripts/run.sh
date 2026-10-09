#!/usr/bin/env bash
set -euo pipefail

C_RESET="\033[0m"
C_BLUE="\033[1;34m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"

log_info()  { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
log_ok()    { echo -e "${C_GREEN}[OK]${C_RESET} $1"; }
log_warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
log_err()   { echo -e "${C_RED}[ERRO]${C_RESET} $1"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# 1. Sanity Check: Binário Java
if ! command -v java &>/dev/null; then
  log_err "Java não encontrado no PATH. Instale o OpenJDK 21 via: sudo dnf install -y java-21-openjdk-headless"
  exit 1
fi

# 2. Sanity Check: Versão do Java >= 21
JAVA_RAW_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
JAVA_MAJOR_VERSION=$(echo "${JAVA_RAW_VERSION}" | awk -F '.' '{print ($1 == "1" ? $2 : $1)}')

if [[ "${JAVA_MAJOR_VERSION}" -lt 21 ]]; then
  log_err "Versão do Java incompatível (${JAVA_RAW_VERSION}). PaperMC 1.21+ exige Java 21 ou superior."
  exit 1
fi
log_ok "Java detectado: versão ${JAVA_RAW_VERSION} (Major: ${JAVA_MAJOR_VERSION})"

# 3. Sanity Check: server.jar
if [[ ! -f "server.jar" ]]; then
  log_err "Arquivo 'server.jar' não encontrado no diretório raiz."
  log_info "Execute o script de download primeiro: bash scripts/download-artifacts.sh"
  exit 1
fi

# 4. Cálculo Dinâmico de RAM com Headroom para SO
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$(( TOTAL_MEM_KB / 1024 / 1024 ))

# Regra: Reserva de 2GB de Headroom para SO, Metaspace, Off-heap buffers
HEADROOM_GB=2

if [[ "${TOTAL_MEM_GB}" -le "${HEADROOM_GB}" ]]; then
  ALLOC_RAM_GB=1
  log_warn "Host com memória muito restrita (${TOTAL_MEM_GB}GB). Alocando heap mínima de 1GB."
else
  CALCULATED_RAM=$(( TOTAL_MEM_GB - HEADROOM_GB ))
  # Limite de segurança padrão para servidores PaperMC em host dedicado
  if [[ "${CALCULATED_RAM}" -gt 14 ]]; then
    ALLOC_RAM_GB=14
  else
    ALLOC_RAM_GB="${CALCULATED_RAM}"
  fi
fi

JVM_MEMORY="${ALLOC_RAM_GB}G"
log_info "Memória do Host: ${TOTAL_MEM_GB}GB | Headroom SO: ${HEADROOM_GB}GB | Heap (-Xms/-Xmx): ${JVM_MEMORY}"

# 5. Execução com Aikar's Flags formais
AIKAR_FLAGS=(
  "-Xms${JVM_MEMORY}"
  "-Xmx${JVM_MEMORY}"
  "-XX:+UseG1GC"
  "-XX:+ParallelRefProcEnabled"
  "-XX:MaxGCPauseMillis=200"
  "-XX:+UnlockExperimentalVMOptions"
  "-XX:+DisableExplicitGC"
  "-XX:+AlwaysPreTouch"
  "-XX:G1NewSizePercent=30"
  "-XX:G1MaxNewSizePercent=40"
  "-XX:G1HeapRegionSize=8M"
  "-XX:G1ReservePercent=20"
  "-XX:G1HeapWastePercent=5"
  "-XX:G1MixedGCCountTarget=4"
  "-XX:InitiatingHeapOccupancyPercent=15"
  "-XX:G1MixedGCLiveThresholdPercent=90"
  "-XX:G1RSetUpdatingPauseTimePercent=5"
  "-XX:SurvivorRatio=32"
  "-XX:+PerfDisableSharedMem"
  "-XX:MaxTenuringThreshold=1"
  "-XX:+UseStringDeduplication"
  "-Dusing.aikars.flags=https://mcflags.emc.gs"
  "-Daikars.new.flags=true"
)

log_ok "Iniciando PaperMC Server com G1GC Otimizado..."
exec java "${AIKAR_FLAGS[@]}" -jar server.jar --nogui
