#!/bin/bash -e

WAIT_TIME=30 #seconds
MC_FLAGS=()
MC_FLAGS+=(${MC_GLOBAL_FLAGS})
OBEJCT_PREFIX=${BACKUP_PREFIX:-$POSTGRES_DATABASE}
if [[ ! -z "$DEBUG" ]]; then
  set -x
fi

echo "[INFO] $(date -u)"

export PGPASSWORD="${POSTGRES_PASSWORD}"
TIMESTAMP="$(date +"%Y_%m_%dT%H_%M_%S")"
S3_BUCKET_PATH="s3/${S3_BUCKET}/${S3_PREFIX/'/'}"
S3_URI_BASE="${S3_BUCKET_PATH}/${OBEJCT_PREFIX}_${TIMESTAMP}.zstd"

echo "[INFO] Creating backup of ${POSTGRES_DATABASE} database..."

function backup() {
  pg_dump -h "${POSTGRES_HOST}" \
          -p "${POSTGRES_PORT}" \
          -U "${POSTGRES_USER}" \
          -d "${POSTGRES_DATABASE}" \
          ${PGDUMP_EXTRA_OPTS} \
    | zstd "-${ZSTD_COMPRESSION_LEVEL:-15}" -T${ZSTD_COMPRESSION_THREADS:-$(nproc)} ${ZSTD_EXTRA_OPTS} \
    | mc pipe ${MC_FLAGS[@]} ${MC_UPLOAD_FLAGS} "${S3_URI_BASE}"
  [[ "${PIPESTATUS[@]}" =~ "1" ]] && return # bash way of return true
  false # bash way of return false
}

count=0
while backup; do
  count=$(( count + 1 ))
  if [[ "${count}" -gt 3 ]]; then
    echo "[ERROR] Something went, backup incomplete"
    echo "[ERROR] $(date -u)"
    exit 1
  fi
  ## Remove false data
  mc rm -r --force ${MC_FLAGS[@]} -r "${S3_URI_BASE}"
  echo "[WARN] Waiting ${WAIT_TIME} second"
  sleep ${WAIT_TIME}
done

echo "[INFO] Backup complete"
echo "[INFO] Backup stats"
mc ls --json ${MC_FLAGS[@]} "${S3_URI_BASE}" | jq

if [[ -n "$KEEP_LAST_BACKUPS" ]]; then
  echo "[INFO] Removing old backups"
  EXISTING_OBJECTS=$(mc find --name "${OBEJCT_PREFIX}*" ${MC_FLAGS[@]} $S3_BUCKET_PATH | wc -l)
  KEEP_ONLY="$(( ${EXISTING_OBJECTS} - ${KEEP_LAST_BACKUPS} ))"
  if [[ "${KEEP_ONLY}" -le 0 ]]; then
    echo "[INFO] There is nothing to remove"
  else
    export IFS=$'\n'
    for object in $(mc find --name "${OBEJCT_PREFIX}*" ${MC_FLAGS[@]/'--json'} --json "${S3_BUCKET_PATH}" | head "-${KEEP_ONLY}" | jq -r '.key'); do
      echo "[INFO] Removing \`${object}\`"
      echo -n '[INFO] '
      mc rm -r --force ${MC_FLAGS[@]} -r "${object}"
      [[ $? != 0 ]] && echo "[WARN] Cannot delete object"
    done
  fi
  echo "[INFO] Removing complete"
fi

echo "[INFO] $(date -u)"
