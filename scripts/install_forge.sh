#!/bin/bash
# scripts/install_forge.sh
# Downloads and installs the Forge server for the requested MC + Forge version.
set -euo pipefail

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [forge] [INFO]  $*"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [forge] [ERROR] $*" >&2; exit 1; }

MINECRAFT_VERSION="${MINECRAFT_VERSION:?MINECRAFT_VERSION is required}"
FORGE_VERSION="${FORGE_VERSION:?FORGE_VERSION is required}"
SERVER_DIR="${SERVER_DIR:-/data}"
INSTALLER_JAR="${SERVER_DIR}/forge-installer.jar"

FORGE_INSTALLER_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${MINECRAFT_VERSION}-${FORGE_VERSION}/forge-${MINECRAFT_VERSION}-${FORGE_VERSION}-installer.jar"

log "Downloading Forge installer for Minecraft ${MINECRAFT_VERSION} / Forge ${FORGE_VERSION}..."
log "URL: ${FORGE_INSTALLER_URL}"

curl --fail --silent --show-error --location \
     --output "${INSTALLER_JAR}" \
     "${FORGE_INSTALLER_URL}" \
  || err "Failed to download Forge installer. Verify MINECRAFT_VERSION=${MINECRAFT_VERSION} and FORGE_VERSION=${FORGE_VERSION}."

log "Running Forge installer (this may take several minutes)..."
java -jar "${INSTALLER_JAR}" --installServer "${SERVER_DIR}" \
  || err "Forge installer failed."

log "Cleaning up installer jar..."
rm -f "${INSTALLER_JAR}"

log "Forge server installation complete."
