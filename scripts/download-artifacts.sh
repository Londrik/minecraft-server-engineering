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
CONFIG_DIR="${ROOT_DIR}/config"
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

# 1. PaperMC / Purpur 1.21.1
log_info "Verificando server.jar..."
if [[ ! -f "${ROOT_DIR}/server.jar" ]] || [[ $(stat -c%s "${ROOT_DIR}/server.jar") -lt 40000000 ]]; then
  log_info "Baixando Paper/Purpur 1.21.1..."
  curl -fL -H "User-Agent: ${UA}" --progress-bar "https://api.purpurmc.org/v2/purpur/1.21.1/latest/download" -o "${ROOT_DIR}/server.jar"
fi
validate_jar "${ROOT_DIR}/server.jar" 40

# 2. GeyserMC
log_info "Baixando GeyserMC..."
curl -fL -H "User-Agent: ${UA}" --progress-bar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" -o "${PLUGINS_DIR}/Geyser-Spigot.jar"
validate_jar "${PLUGINS_DIR}/Geyser-Spigot.jar" 30

# 3. Floodgate
log_info "Baixando Floodgate..."
curl -fL -H "User-Agent: ${UA}" --progress-bar "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" -o "${PLUGINS_DIR}/Floodgate-Spigot.jar"
validate_jar "${PLUGINS_DIR}/Floodgate-Spigot.jar" 5

# 4. ViaVersion (Compatibilidade de protocolo entre clientes novos e servidor)
log_info "Baixando ViaVersion estável..."
curl -fL -H "User-Agent: ${UA}" --progress-bar "https://ci.viaversion.com/job/ViaVersion/lastSuccessfulBuild/artifact/build/libs/ViaVersion-5.2.1.jar" -o "${PLUGINS_DIR}/ViaVersion.jar" || \
curl -fL -H "User-Agent: ${UA}" --progress-bar "https://github.com/ViaVersion/ViaVersion/releases/latest/download/ViaVersion.jar" -o "${PLUGINS_DIR}/ViaVersion.jar"
validate_jar "${PLUGINS_DIR}/ViaVersion.jar" 2

if [[ -f "${CONFIG_DIR}/geyser/config.yml" ]]; then
  mkdir -p "${PLUGINS_DIR}/Geyser-Spigot"
  cp -n "${CONFIG_DIR}/geyser/config.yml" "${PLUGINS_DIR}/Geyser-Spigot/config.yml" || true
fi

chmod +x "${BASH_SOURCE[0]}"
log_ok "Todos os artefatos validados com sucesso!"
