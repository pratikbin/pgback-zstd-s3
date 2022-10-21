#!/bin/bash -e

MC_FLAGS=()
MC_FLAGS+=(${MC_GLOBAL_FLAGS})
if [[ ! -z "$DEBUG" ]]; then
  set -x
fi

function checkCommandExist(){
  if ! command -v ${1} > /dev/null; then
    echo "[ERROR] Can't find \'${1}\' executable. Aborted."
    exit 1
  fi
}

checkCommandExist mc
checkCommandExist zstd
checkCommandExist jq

if [[ -z "${S3_ACCESS_KEY_ID}" ]]; then
  echo "[ERROR] You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [[ -z "${S3_SECRET_ACCESS_KEY}" ]]; then
  echo "[ERROR] You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [[ -z "${S3_BUCKET}" ]]; then
  echo "[ERROR] You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [[ -z "${POSTGRES_DATABASE}" ]]; then
  echo "[ERROR] You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [[ -z "${POSTGRES_HOST}" ]]; then
  if [[ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]]; then
    POSTGRES_HOST="${POSTGRES_PORT_5432_TCP_ADDR}"
    POSTGRES_PORT="${POSTGRES_PORT_5432_TCP_PORT}"
  else
    echo "[ERROR] You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [[ -z "${POSTGRES_PORT}" ]]; then
  echo "[WARN] Using Postgres default port 5432"
  export POSTGRES_PORT=5432
fi

if [[ -z "${POSTGRES_USER}" ]]; then
  echo "[ERROR] You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [[ "${KEEP_LAST_BACKUPS}" -le 0 ]]; then
  echo "[WARN] env KEEP_LAST_BACKUPS is not test, keeping all backups"
fi

echo "[INFO] Using zstd compression level: ${ZSTD_COMPRESSION_LEVE:-15}"

if [[ -n "${S3_ENDPOINT}" ]]; then
  mc alias set ${MC_FLAGS[@]} "s3" "${S3_ENDPOINT}" "${S3_ACCESS_KEY_ID}" "${S3_SECRET_ACCESS_KEY}"
else
  mc alias set ${MC_FLAGS[@]} "s3" "https://s3.amazonaws.com" "${S3_ACCESS_KEY_ID}" "${S3_SECRET_ACCESS_KEY}"
fi

if [[ "${MODE}" == "RESTORE" || "${MODE}" == "restore" ]]; then
  exec /restore.sh
  exit 0
else
  if [[ -z "${SCHEDULE}" ]]; then
    exec /backup.sh
  else
    [[ -n "${BACKUP_ON_START}" ]] && /backup.sh
    echo -n "[INFO] Starting "
    exec go-cron "${SCHEDULE}" /backup.sh
  fi
fi
