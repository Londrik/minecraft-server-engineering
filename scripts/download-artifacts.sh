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

USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) mc-crossplay-installer"

# 1. Download PaperMC
log_info "Buscando versão estável do PaperMC (1.21.x)..."
PAPER_API_BASE="https://api.papermc.io/v2/projects/paper"

PAPER_DOWNLOADED=false
PROJECT_JSON=$(curl -sSL -H "User-Agent: ${USER_AGENT}" "${PAPER_API_BASE}" || true)

if [[ -n "${PROJECT_JSON}" ]] && echo "${PROJECT_JSON}" | grep -q '"versions"'; then
  LATEST_VERSION=$(echo "${PROJECT_JSON}" | jq -r '.versions[]' | grep '^1\.21' | tail -n 1 || true)
  if [[ -z "${LATEST_VERSION}" || "${LATEST_VERSION}" == "null" ]]; then
    LATEST_VERSION=$(echo "${PROJECT_JSON}" | jq -r '.versions[-1]')
  fi

  VERSION_JSON=$(curl -sSL -H "User-Agent: ${USER_AGENT}" "${PAPER_API_BASE}/versions/${LATEST_VERSION}" || true)
  LATEST_BUILD=$(echo "${VERSION_JSON}" | jq -r '.builds[-1]' || true)

  if [[ -n "${LATEST_BUILD}" && "${LATEST_BUILD}" != "null" ]]; then
    BUILD_JSON=$(curl -sSL -H "User-Agent: ${USER_AGENT}" "${PAPER_API_BASE}/versions/${LATEST_VERSION}/builds/${LATEST_BUILD}" || true)
    APP_JAR=$(echo "${BUILD_JSON}" | jq -r '.downloads.application.name' || true)
    if [[ -n "${APP_JAR}" && "${APP_JAR}" != "null" ]]; then
      DOWNLOAD_URL="${PAPER_API_BASE}/versions/${LATEST_VERSION}/builds/${LATEST_BUILD}/downloads/${APP_JAR}"
      log_info "Baixando Paper ${LATEST_VERSION} (Build #${LATEST_BUILD})..."
      curl -sSL -H "User-Agent: ${USER_AGENT}" --progress-bar "${DOWNLOAD_URL}" -o "${ROOT_DIR}/server.jar"
      PAPER_DOWNLOADED=true
    fi
  fi
fi

if [[ "${PAPER_DOWNLOADED}" == "false" ]]; then
  log_warn "API PaperMC indisponível ou rota descontinuada. Utilizando fallback direto para Paper 1.21..."
  FALLBACK_URL="https://api.papermc.io/v2/projects/paper/versions/1.21.1/builds/130/downloads/paper-1.21.1-130.jar"
  curl -sSL -H "User-Agent: ${USER_AGENT}" --progress-bar "${FALLBACK_URL}" -o "${ROOT_DIR}/server.jar" || {
    # Fallback espelho purpur/paper build estável
    curl -sSL --progress-bar "https://fill.papermc.io/v2/projects/paper/versions/1.21.1/builds/latest/downloads/paper-1.21.1.jar" -o "${ROOT_DIR}/server.jar"
  }
fi
log_ok "PaperMC salvo com sucesso em server.jar"

# 2. Download GeyserMC (Paper/Spigot)
log_info "Baixando GeyserMC (Spigot/Paper flavor)..."
GEYSER_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
curl -sSL -H "User-Agent: ${USER_AGENT}" --progress-bar "${GEYSER_URL}" -o "${PLUGINS_DIR}/Geyser-Spigot.jar"
log_ok "GeyserMC salvo em plugins/Geyser-Spigot.jar"

# 3. Download Floodgate (Paper/Spigot)
log_info "Baixando Floodgate (Spigot/Paper flavor)..."
FLOODGATE_URL="https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
curl -sSL -H "User-Agent: ${USER_AGENT}" --progress-bar "${FLOODGATE_URL}" -o "${PLUGINS_DIR}/Floodgate-Spigot.jar"
log_ok "Floodgate salvo em plugins/Floodgate-Spigot.jar"

# 4. Download Spark Profiler
log_info "Baixando Spark Profiler..."
SPARK_URL="https://ci.lucko.me/job/spark/lastSuccessfulBuild/artifact/spark-bukkit/build/libs/spark-bukkit.jar"
curl -sSL -H "User-Agent: ${USER_AGENT}" --progress-bar "${SPARK_URL}" -o "${PLUGINS_DIR}/spark.jar"
log_ok "Spark Profiler salvo em plugins/spark.jar"

chmod +x "${BASH_SOURCE[0]}"
log_ok "Todos os artefatos foram baixados com sucesso!"
