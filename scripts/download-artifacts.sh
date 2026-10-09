#!/usr/bin/env bash
set -euo pipefail

# Cores para feedback visual no terminal
C_RESET="\033[0m"
C_BLUE="\033[1;34m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"

log_info()  { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
log_ok()    { echo -e "${C_GREEN}[OK]${C_RESET} $1"; }
log_warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
log_err()   { echo -e "${C_RED}[ERRO]${C_RESET} $1"; }

# Dependências obrigatórias
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    log_err "Binário obrigatório ausente: '$cmd'. Instale via: sudo dnf install -y $cmd"
    exit 1
  fi
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="${ROOT_DIR}/plugins"
mkdir -p "${PLUGINS_DIR}"

# 1. Download PaperMC (1.21+) via REST API v2
log_info "Consultando API PaperMC para a versão 1.21+ mais recente..."
PAPER_API_BASE="https://api.papermc.io/v2/projects/paper"

PROJECT_DATA=$(curl -sSf "${PAPER_API_BASE}")
LATEST_VERSION=$(echo "${PROJECT_DATA}" | jq -r '.versions[]' | grep '^1\.2[1-9]' | tail -n 1)

if [[ -z "${LATEST_VERSION}" || "${LATEST_VERSION}" == "null" ]]; then
  LATEST_VERSION=$(echo "${PROJECT_DATA}" | jq -r '.versions[-1]')
  log_warn "Versão 1.21+ não detectada explicitamente. Usando versão mais recente: ${LATEST_VERSION}"
fi

VERSION_DATA=$(curl -sSf "${PAPER_API_BASE}/versions/${LATEST_VERSION}")
LATEST_BUILD=$(echo "${VERSION_DATA}" | jq -r '.builds[-1]')
APPLICATION_JAR=$(curl -sSf "${PAPER_API_BASE}/versions/${LATEST_VERSION}/builds/${LATEST_BUILD}" | jq -r '.downloads.application.name')

PAPER_DOWNLOAD_URL="${PAPER_API_BASE}/versions/${LATEST_VERSION}/builds/${LATEST_BUILD}/downloads/${APPLICATION_JAR}"
log_info "Baixando PaperMC ${LATEST_VERSION} (Build #${LATEST_BUILD})..."
curl -sSL --progress-bar "${PAPER_DOWNLOAD_URL}" -o "${ROOT_DIR}/server.jar"
log_ok "PaperMC salvo com sucesso em server.jar"

# 2. Download GeyserMC (Spigot/Paper)
log_info "Baixando GeyserMC (Spigot/Paper flavor)..."
GEYSER_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
curl -sSL --progress-bar "${GEYSER_URL}" -o "${PLUGINS_DIR}/Geyser-Spigot.jar"
log_ok "GeyserMC salvo em plugins/Geyser-Spigot.jar"

# 3. Download Floodgate (Spigot/Paper)
log_info "Baixando Floodgate (Spigot/Paper flavor)..."
FLOODGATE_URL="https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
curl -sSL --progress-bar "${FLOODGATE_URL}" -o "${PLUGINS_DIR}/Floodgate-Spigot.jar"
log_ok "Floodgate salvo em plugins/Floodgate-Spigot.jar"

# 4. Download Spark Profiler (Bukkit/Paper)
log_info "Consultando API oficial do Spark Profiler..."
SPARK_METADATA=$(curl -sSf "https://spark.lucko.me/api/download?platform=bukkit")
SPARK_URL=$(echo "${SPARK_METADATA}" | jq -r '.url')

if [[ -z "${SPARK_URL}" || "${SPARK_URL}" == "null" ]]; then
  SPARK_URL="https://ci.lucko.me/job/spark/lastSuccessfulBuild/artifact/spark-bukkit/build/libs/spark-bukkit.jar"
  log_warn "Fallback para build estável do Spark..."
fi

log_info "Baixando Spark Profiler..."
curl -sSL --progress-bar "${SPARK_URL}" -o "${PLUGINS_DIR}/spark.jar"
log_ok "Spark Profiler salvo em plugins/spark.jar"

chmod +x "${BASH_SOURCE[0]}"
log_ok "Download de todos os artefatos concluído com sucesso."
