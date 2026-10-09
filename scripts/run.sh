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

JAVA_BIN=""
if [[ -x "$HOME/.jdks/temurin-21/bin/java" ]]; then
  JAVA_BIN="$HOME/.jdks/temurin-21/bin/java"
elif [[ -x "/usr/lib/jvm/java-21-openjdk/bin/java" ]]; then
  JAVA_BIN="/usr/lib/jvm/java-21-openjdk/bin/java"
elif command -v java &>/dev/null; then
  JAVA_BIN="$(command -v java)"
else
  log_err "Nenhum binário Java encontrado no sistema."
  exit 1
fi

JAVA_RAW=$("${JAVA_BIN}" -version 2>&1 | awk -F '"' '/version/ {print $2}')
log_ok "Ambiente JVM: ${JAVA_BIN} (${JAVA_RAW})"

if [[ ! -f "server.jar" ]]; then
  log_err "server.jar ausente."
  exit 1
fi

TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$(( TOTAL_MEM_KB / 1024 / 1024 ))
HEADROOM_GB=2

if [[ "${TOTAL_MEM_GB}" -le "${HEADROOM_GB}" ]]; then
  ALLOC_RAM_GB=1
else
  CALCULATED_RAM=$(( TOTAL_MEM_GB - HEADROOM_GB ))
  ALLOC_RAM_GB=$(( CALCULATED_RAM > 12 ? 12 : CALCULATED_RAM ))
fi

JVM_MEMORY="${ALLOC_RAM_GB}G"
log_info "Memória Host: ${TOTAL_MEM_GB}GB | Headroom: ${HEADROOM_GB}GB | Heap (-Xms/-Xmx): ${JVM_MEMORY}"

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
  "--add-modules=jdk.incubator.vector"
)

log_ok "Iniciando PaperMC com otimizações SIMD ativas..."
exec "${JAVA_BIN}" "${AIKAR_FLAGS[@]}" -jar server.jar --nogui
