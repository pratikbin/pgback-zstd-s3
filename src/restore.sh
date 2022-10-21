#!/bin/bash -

WAIT_TIME=30 #seconds
MC_FLAGS=()
MC_FLAGS+=(${MC_GLOBAL_FLAGS})
OBEJCT_PREFIX=${BACKUP_PREFIX:-$POSTGRES_DATABASE}

if [[ ! -z "$DEBUG" ]]; then
  set -x
fi

echo "[INFO] $(date -u)"

S3_URI_BASE="s3/${S3_BUCKET}/${S3_PREFIX}"

if [[ -n "${RESTORE_VERSION}" ]]; then
  echo "[INFO] Finding ${RESTORE_VERSION} backup..."
  KEY_SUFFIX="$(mc ls --json ${MC_FLAGS[@]/'--json'} "${S3_URI_BASE}/${RESTORE_VERSION}" | jq -r '.key')"
else
  echo "[INFO] Finding latest backup..."
  KEY_SUFFIX=$(mc ls --json ${MC_FLAGS[@]/'--json'} "${S3_URI_BASE}" | tail -n1 | jq -r '.key')
fi

if [[ -z "${KEY_SUFFIX}" ]]; then
  echo "[ERROR] Could not find backup"
  exit 1
fi

export PGPASSWORD="${POSTGRES_PASSWORD}"
echo "[INFO] Restoring backup from S3 to postgres..."
function restore(){
  mc cat "${S3_URI_BASE}/${KEY_SUFFIX}" \
    | zstd -d -T$(nproc) \
    | psql \
      -h "${POSTGRES_HOST}" \
      -p "${POSTGRES_PORT}" \
      -U "${POSTGRES_USER}" \
      ${PGRESTORE_EXTRA_OPTS}
  [[ "${PIPESTATUS[@]}" =~ "1" ]] && return # bash way of return true
  false # bash way of return false
}

while restore; do
  echo "[ERROR] Something went restores incomplete"
  echo "[ERROR] $(date -u)"
  exit 1
done

echo "[INFO] Restore complete"
echo "[INFO] $(date -u)"
