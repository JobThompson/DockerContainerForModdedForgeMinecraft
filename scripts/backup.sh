#!/bin/bash
# scripts/backup.sh
# Creates a timestamped compressed backup of the world directory.
# Intended for use with cron inside the container or called externally.
set -euo pipefail

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [backup] [INFO]  $*"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [backup] [WARN]  $*" >&2; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [backup] [ERROR] $*" >&2; exit 1; }

SERVER_DIR="${SERVER_DIR:-/data}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
WORLD_NAME="${WORLD_NAME:-}"
BACKUP_RETAIN_DAYS="${BACKUP_RETAIN_DAYS:-7}"

if [[ -z "${WORLD_NAME}" && -f "${SERVER_DIR}/server.properties" ]]; then
  WORLD_NAME="$(sed -n 's/^[[:space:]]*level-name[[:space:]]*=[[:space:]]*//p' "${SERVER_DIR}/server.properties" | tail -n1 | tr -d '\r' | sed 's/[[:space:]]*$//')"
fi

WORLD_NAME="${WORLD_NAME:-world}"
[[ "${WORLD_NAME}" =~ ^[A-Za-z0-9._-]+$ ]] || err "WORLD_NAME \"${WORLD_NAME}\" contains invalid characters. Only alphanumeric, dot, underscore, and hyphen are allowed."
[[ "${BACKUP_RETAIN_DAYS}" =~ ^[0-9]+$ ]] || err "BACKUP_RETAIN_DAYS must be a non-negative integer."
WORLD_DIR="${SERVER_DIR}/${WORLD_NAME}"

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

if [[ ! -d "${WORLD_DIR}" ]]; then
  warn "World directory ${WORLD_DIR} does not exist. Nothing to back up."
  exit 0
fi

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/${WORLD_NAME}_backup_${TIMESTAMP}.tar.gz"

log "Starting backup of ${WORLD_DIR} to ${BACKUP_FILE}..."
tar -czf "${BACKUP_FILE}" -C "${SERVER_DIR}" "${WORLD_NAME}" \
  || err "Failed to create backup archive."

log "Backup complete: ${BACKUP_FILE} ($(du -sh "${BACKUP_FILE}" | cut -f1))"

# Remove backups older than BACKUP_RETAIN_DAYS
log "Removing backups older than ${BACKUP_RETAIN_DAYS} days..."
find "${BACKUP_DIR}" -maxdepth 1 -name "${WORLD_NAME}_backup_*.tar.gz" \
     -mtime +${BACKUP_RETAIN_DAYS} -delete
log "Old backups cleaned up."
