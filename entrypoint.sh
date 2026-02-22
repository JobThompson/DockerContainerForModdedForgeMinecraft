#!/bin/bash
# entrypoint.sh - Main container startup script
# Validates environment, installs modloader, syncs modpack files, and launches server.
set -euo pipefail

# ─── Logging helpers ─────────────────────────────────────────────────────────
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" >&2; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; exit 1; }

# ─── Environment defaults ─────────────────────────────────────────────────────
MODLOADER="${MODLOADER:-}"
MINECRAFT_VERSION="${MINECRAFT_VERSION:-}"
FORGE_VERSION="${FORGE_VERSION:-}"
FABRIC_LOADER_VERSION="${FABRIC_LOADER_VERSION:-}"
JAVA_MEMORY="${JAVA_MEMORY:-4G}"
EULA="${EULA:-false}"
SERVER_DIR="/data"
MODPACK_DIR="/servers/modpack"

# ─── Validate required environment variables ─────────────────────────────────
log "Validating environment variables..."

[[ -z "${MODLOADER}" ]]         && err "MODLOADER must be set to 'forge' or 'fabric'."
[[ -z "${MINECRAFT_VERSION}" ]] && err "MINECRAFT_VERSION must be set (e.g. 1.20.1)."

case "${MODLOADER,,}" in
  forge)
    [[ -z "${FORGE_VERSION}" ]] && err "FORGE_VERSION must be set when MODLOADER=forge (e.g. 47.2.0)."
    ;;
  fabric)
    [[ -z "${FABRIC_LOADER_VERSION}" ]] && err "FABRIC_LOADER_VERSION must be set when MODLOADER=fabric (e.g. 0.15.7)."
    ;;
  *)
    err "Unknown MODLOADER '${MODLOADER}'. Supported values: forge, fabric."
    ;;
esac

if [[ "${EULA,,}" != "true" ]]; then
  err "You must accept the Minecraft EULA by setting EULA=true."
fi

log "MODLOADER=${MODLOADER}, MINECRAFT_VERSION=${MINECRAFT_VERSION}, JAVA_MEMORY=${JAVA_MEMORY}"

# ─── Write EULA file ─────────────────────────────────────────────────────────
log "Writing eula.txt..."
echo "eula=true" > "${SERVER_DIR}/eula.txt"

# ─── Helper: detect existing Forge installation ───────────────────────────────
is_forge_installed() {
  # Modern Forge creates a run.sh; legacy installs produce a fat jar.
  [[ -f "${SERVER_DIR}/run.sh" ]] && return 0
  [[ -f "${SERVER_DIR}/forge-server.jar" ]] && return 0
  [[ -f "${SERVER_DIR}/libraries/net/minecraftforge/forge/${MINECRAFT_VERSION}-${FORGE_VERSION}/forge-${MINECRAFT_VERSION}-${FORGE_VERSION}-server.jar" ]] && return 0
  return 1
}

# ─── Install modloader (only if server jar is absent) ────────────────────────
case "${MODLOADER,,}" in
  forge)
    if is_forge_installed; then
      log "Forge server already installed, skipping installation."
    else
      log "Installing Forge server..."
      /scripts/install_forge.sh
    fi
    ;;
  fabric)
    if [[ ! -f "${SERVER_DIR}/fabric-server-launch.jar" ]]; then
      log "Installing Fabric server..."
      /scripts/install_fabric.sh
    else
      log "Fabric server already installed, skipping installation."
    fi
    ;;
esac

# ─── Sync modpack files ───────────────────────────────────────────────────────
# Copy modpack files from /servers/modpack into /data on every start so that
# dropping new files and restarting the container is all that's required to
# update the server.
if [[ -d "${MODPACK_DIR}" ]]; then
  log "Syncing modpack files from ${MODPACK_DIR} to ${SERVER_DIR}..."
  cp -af "${MODPACK_DIR}/." "${SERVER_DIR}/"
  log "Modpack files synced."
else
  warn "Modpack directory ${MODPACK_DIR} not found. Skipping sync."
fi

# ─── JVM flags ───────────────────────────────────────────────────────────────
JVM_FLAGS=(
  "-Xms${JAVA_MEMORY}"
  "-Xmx${JAVA_MEMORY}"
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
  "-Dusing.aikars.flags=https://mcflags.emc.gs"
  "-Daikars.new.flags=true"
)

# ─── Determine server jar and launch command ──────────────────────────────────
cd "${SERVER_DIR}"

case "${MODLOADER,,}" in
  forge)
    # Modern Forge (1.17+) generates a run.sh / user_jvm_args.txt; use it when
    # present, otherwise fall back to the legacy fat jar.
    if [[ -f "${SERVER_DIR}/run.sh" ]]; then
      log "Starting Forge server via run.sh..."
      # Patch @user_jvm_args.txt with our memory flags if it exists
      if [[ -f "${SERVER_DIR}/user_jvm_args.txt" ]]; then
        {
          echo "-Xms${JAVA_MEMORY}"
          echo "-Xmx${JAVA_MEMORY}"
        } > "${SERVER_DIR}/user_jvm_args.txt"
      fi
      exec bash "${SERVER_DIR}/run.sh" nogui
    else
      # Locate legacy forge jar (warn if multiple matches)
      mapfile -t FORGE_JARS < <(find "${SERVER_DIR}" -maxdepth 1 -name "forge-*.jar")
      if [[ ${#FORGE_JARS[@]} -gt 1 ]]; then
        warn "Multiple Forge jars found; using: ${FORGE_JARS[0]}. Remove stale jars to avoid ambiguity."
      fi
      FORGE_JAR="${FORGE_JARS[0]:-}"
      [[ -z "${FORGE_JAR}" ]] && err "Could not find Forge server jar in ${SERVER_DIR}."
      log "Starting Forge server: ${FORGE_JAR}"
      exec java "${JVM_FLAGS[@]}" -jar "${FORGE_JAR}" nogui
    fi
    ;;
  fabric)
    FABRIC_JAR="${SERVER_DIR}/fabric-server-launch.jar"
    [[ ! -f "${FABRIC_JAR}" ]] && err "Fabric server jar not found: ${FABRIC_JAR}"
    log "Starting Fabric server: ${FABRIC_JAR}"
    exec java "${JVM_FLAGS[@]}" -jar "${FABRIC_JAR}" nogui
    ;;
esac
