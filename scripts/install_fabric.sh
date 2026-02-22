#!/bin/bash
# scripts/install_fabric.sh
# Downloads and installs the Fabric server for the requested MC + loader version.
set -euo pipefail

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [fabric] [INFO]  $*"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [fabric] [ERROR] $*" >&2; exit 1; }

MINECRAFT_VERSION="${MINECRAFT_VERSION:?MINECRAFT_VERSION is required}"
FABRIC_LOADER_VERSION="${FABRIC_LOADER_VERSION:?FABRIC_LOADER_VERSION is required}"
SERVER_DIR="${SERVER_DIR:-/data}"
INSTALLER_JAR="${SERVER_DIR}/fabric-installer.jar"

# Resolve the latest Fabric installer version via the Fabric meta API
FABRIC_INSTALLER_VERSION=$(
  curl --fail --silent --show-error \
       "https://meta.fabricmc.net/v2/versions/installer" \
  | jq -r '.[0].version' \
) || err "Failed to retrieve Fabric installer version from Fabric meta API."

FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER_VERSION}/fabric-installer-${FABRIC_INSTALLER_VERSION}.jar"

log "Fabric installer version: ${FABRIC_INSTALLER_VERSION}"
log "Downloading Fabric installer..."
log "URL: ${FABRIC_INSTALLER_URL}"

curl --fail --silent --show-error --location \
     --output "${INSTALLER_JAR}" \
     "${FABRIC_INSTALLER_URL}" \
  || err "Failed to download Fabric installer."

log "Running Fabric installer for Minecraft ${MINECRAFT_VERSION} / loader ${FABRIC_LOADER_VERSION}..."
java -jar "${INSTALLER_JAR}" server \
     -mcversion "${MINECRAFT_VERSION}" \
     -loader "${FABRIC_LOADER_VERSION}" \
     -downloadMinecraft \
     -dir "${SERVER_DIR}" \
  || err "Fabric installer failed. Verify MINECRAFT_VERSION=${MINECRAFT_VERSION} and FABRIC_LOADER_VERSION=${FABRIC_LOADER_VERSION}."

log "Cleaning up installer jar..."
rm -f "${INSTALLER_JAR}"

log "Fabric server installation complete."
