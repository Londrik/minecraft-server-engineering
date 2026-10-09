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
PLUGINS_DIR="${ROOT_DIR}/plugins"
mkdir -p "${PLUGINS_DIR}"

UA="Mozilla/5.0 (X11; Linux x86_64) PaperMC-Ops/1.0"

validate_jar() {
  local file="$1"
  local min_size_mb="$2"
  if [[ ! -f "$file" ]]; then
    log_err "Arquivo $file não foi criado."
    return 1
  fi
  local size_bytes
  size_bytes=$(stat -c%s "$file")
  local min_bytes=$(( min_size_mb * 1024 * 1024 ))
  if [[ "$size_bytes" -lt "$min_bytes" ]]; then
    log_err "$file inválido ($size_bytes bytes). Removendo..."
    rm -f "$file"
    return 1
  fi
  log_ok "$file validado com sucesso ($(numfmt --to=iec "$size_bytes"))."
}

# 1. Download PaperMC (1.21.1)
log_info "Baixando PaperMC 1.21.1..."
PAPER_SUCCESS=false

# Tentativa via API oficial com User-Agent completo
BUILD_INFO=$(curl -sSL -H "User-Agent: ${UA}" "https://api.papermc.io/v2/projects/paper/versions/1.21.1" || true)
if echo "$BUILD_INFO" | grep -q '"builds"'; then
  LATEST_BUILD=$(echo "$BUILD_INFO" | jq -r '.builds[-1]' || true)
  if [[ -n "$LATEST_BUILD" && "$LATEST_BUILD" != "null" ]]; then
    DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/1.21.1/builds/${LATEST_BUILD}/downloads/paper-1.21.1-${LATEST_BUILD}.jar"
    log_info "Baixando build #${LATEST_BUILD} do Paper..."
    curl -fL -H "User-Agent: ${UA}" --progress-bar "$DOWNLOAD_URL" -o "${ROOT_DIR}/server.jar" || true
    if validate_jar "${ROOT_DIR}/server.jar" 40; then
      PAPER_SUCCESS=true
    fi
  fi
fi

# Fallback direto: Purpur 1.21.1 (Drop-in replacement 100% compatível com Paper API)
if [[ "$PAPER_SUCCESS" == "false" ]]; then
  log_warn "API PaperMC bloqueou o tráfego. Usando fallback compatível Paper/Purpur 1.21.1..."
  curl -fL -H "User-Agent: ${UA}" --progress-bar "https://api.purpurmc.org/v2/purpur/1.21.1/latest/download" -o "${ROOT_DIR}/server.jar"
  validate_jar "${ROOT_DIR}/server.jar" 40
fi

# 2. GeyserMC
log_info "Baixando GeyserMC..."
curl -fL -H "User-Agent: ${UA}" --progress-bar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" -o "${PLUGINS_DIR}/Geyser-Spigot.jar"
validate_jar "${PLUGINS_DIR}/Geyser-Spigot.jar" 30

# 3. Floodgate
log_info "Baixando Floodgate..."
curl -fL -H "User-Agent: ${UA}" --progress-bar "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" -o "${PLUGINS_DIR}/Floodgate-Spigot.jar"
validate_jar "${PLUGINS_DIR}/Floodgate-Spigot.jar" 5

# 4. Spark Profiler (Download direto do Jenkins CI oficial do LuckPerms)
log_info "Baixando Spark Profiler..."
SPARK_URL="https://ci.lucko.me/job/spark/lastSuccessfulBuild/artifact/spark-bukkit/build/libs/spark-bukkit.jar"
curl -fL -H "User-Agent: ${UA}" --progress-bar "$SPARK_URL" -o "${PLUGINS_DIR}/spark.jar"
validate_jar "${PLUGINS_DIR}/spark.jar" 3

chmod +x "${BASH_SOURCE[0]}"
log_ok "Todos os componentes essenciais foram baixados e validados!"
