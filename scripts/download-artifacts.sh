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
    log_err "$file corrompido ou resposta HTML ($size_bytes bytes). Removendo..."
    rm -f "$file"
    return 1
  fi
  log_ok "$file validado com sucesso ($(numfmt --to=iec "$size_bytes"))."
}

# 1. Download PaperMC via API oficial v2 com parse robusto
log_info "Consultando builds do PaperMC 1.21.1..."
PAPER_PROJECT_URL="https://api.papermc.io/v2/projects/paper/versions/1.21.1"
LATEST_BUILD=$(curl -sSL "$PAPER_PROJECT_URL" | jq -r '.builds[-1]')

if [[ -z "$LATEST_BUILD" || "$LATEST_BUILD" == "null" ]]; then
  log_warn "API metadata falhou, usando build 131 fixo..."
  LATEST_BUILD="131"
fi

PAPER_FILE="paper-1.21.1-${LATEST_BUILD}.jar"
PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/1.21.1/builds/${LATEST_BUILD}/downloads/${PAPER_FILE}"

log_info "Baixando PaperMC 1.21.1 (Build #${LATEST_BUILD})..."
curl -sSL --progress-bar "$PAPER_URL" -o "${ROOT_DIR}/server.jar"
validate_jar "${ROOT_DIR}/server.jar" 40

# 2. GeyserMC
log_info "Baixando GeyserMC..."
curl -sSL --progress-bar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" -o "${PLUGINS_DIR}/Geyser-Spigot.jar"
validate_jar "${PLUGINS_DIR}/Geyser-Spigot.jar" 30

# 3. Floodgate
log_info "Baixando Floodgate..."
curl -sSL --progress-bar "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" -o "${PLUGINS_DIR}/Floodgate-Spigot.jar"
validate_jar "${PLUGINS_DIR}/Floodgate-Spigot.jar" 5

# 4. Spark Profiler (Github Releases do repositório oficial LuckPerms/spark)
log_info "Consultando release estável do Spark Profiler no GitHub..."
SPARK_DOWNLOAD_URL=$(curl -sSL "https://api.github.com/repos/lucko/spark/releases/latest" | jq -r '.assets[] | select(.name | test("spark-.*-bukkit\\.jar$|spark-bukkit\\.jar$")) | .browser_download_url' | head -n 1)

if [[ -z "$SPARK_DOWNLOAD_URL" || "$SPARK_DOWNLOAD_URL" == "null" ]]; then
  SPARK_DOWNLOAD_URL="https://ci.lucko.me/job/spark/lastSuccessfulBuild/artifact/spark-bukkit/build/libs/spark-bukkit.jar"
fi

log_info "Baixando Spark..."
curl -sSL --progress-bar "$SPARK_DOWNLOAD_URL" -o "${PLUGINS_DIR}/spark.jar"
validate_jar "${PLUGINS_DIR}/spark.jar" 3

chmod +x "${BASH_SOURCE[0]}"
log_ok "Todos os JARs reais foram baixados e validados!"
