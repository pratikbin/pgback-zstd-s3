#!/bin/bash -e

WAIT_TIME=30 #seconds
MC_FLAGS=()
MC_FLAGS+=(${MC_GLOBAL_FLAGS})
OBJECT_PREFIX=${BACKUP_PREFIX:-$POSTGRES_DATABASE}
if [[ ! -z "$DEBUG" ]]; then
  set -x
fi

# Remove leading/trailing slashes from S3_PREFIX
S3_PREFIX_CLEANED="${S3_PREFIX#/}"
S3_PREFIX_CLEANED="${S3_PREFIX_CLEANED%/}"

echo "[INFO] $(date -u)"

export PGPASSWORD="${POSTGRES_PASSWORD}"
TIMESTAMP="$(date +"%Y_%m_%dT%H_%M_%S")"
S3_BUCKET_PATH="s3/${S3_BUCKET}/${S3_PREFIX_CLEANED}"
S3_URI_BASE="${S3_BUCKET_PATH}/${OBJECT_PREFIX}_${TIMESTAMP}.zstd"

echo "[INFO] Creating backup of ${POSTGRES_DATABASE} database..."

function backup() {
  pg_dump -h "${POSTGRES_HOST}" \
          -p "${POSTGRES_PORT}" \
          -U "${POSTGRES_USER}" \
          -d "${POSTGRES_DATABASE}" \
          ${PGDUMP_EXTRA_OPTS} \
    | zstd "-${ZSTD_COMPRESSION_LEVEL:-15}" -T${ZSTD_COMPRESSION_THREADS:-$(nproc)} ${ZSTD_EXTRA_OPTS} \
    | mc pipe "${MC_FLAGS[@]}" ${MC_UPLOAD_FLAGS} "${S3_URI_BASE}"
  local status1=${PIPESTATUS[0]}
  local status2=${PIPESTATUS[1]}
  local status3=${PIPESTATUS[2]}
  if [[ $status1 -ne 0 || $status2 -ne 0 || $status3 -ne 0 ]]; then
    echo "[ERROR] One of the backup pipeline commands failed: pg_dump=$status1, zstd=$status2, mc pipe=$status3"
    return 1
  fi
  return 0
}

count=0
max_retries=3
until backup; do
  count=$(( count + 1 ))
  if [[ "${count}" -ge ${max_retries} ]]; then
    echo "[ERROR] Backup failed after ${max_retries} attempts, backup incomplete"
    echo "[ERROR] $(date -u)"
    exit 1
  fi
  # Remove false data
  mc rm -r --force "${MC_FLAGS[@]}" -r "${S3_URI_BASE}" || echo "[WARN] Failed to remove incomplete backup at ${S3_URI_BASE}"
  echo "[WARN] Waiting ${WAIT_TIME} seconds before retry"
  sleep ${WAIT_TIME}
done

echo "[INFO] Backup complete"
echo "[INFO] Backup stats"
mc ls --json "${MC_FLAGS[@]/'--json'}" "${S3_URI_BASE}" | jq
# Remove backup if it's less than a KB because it's false positive
backup_size=$(mc ls --json "${MC_FLAGS[@]/'--json'}" "${S3_URI_BASE}" | jq -r '.size')
if [[ $(( backup_size / 1024 )) -le 0 ]]; then
  echo "[INFO] looks like backup was not successful (size: $backup_size bytes)"
  mc rm --force "${MC_FLAGS[@]}" "${S3_URI_BASE}"
  exit 1
fi

if [[ -n "$KEEP_LAST_BACKUPS" ]]; then
  echo "[INFO] Removing old backups"
  EXISTING_OBJECTS=$(mc find --name "${OBJECT_PREFIX}*" "${MC_FLAGS[@]}" "$S3_BUCKET_PATH" | wc -l)
  KEEP_ONLY="$(( ${EXISTING_OBJECTS} - ${KEEP_LAST_BACKUPS} ))"
  if [[ "${KEEP_ONLY}" -le 0 ]]; then
    echo "[INFO] There is nothing to remove"
  else
    export IFS=$'\n'
    for object in $(mc find --name "${OBJECT_PREFIX}*" "${MC_FLAGS[@]/'--json'}" --json "${S3_BUCKET_PATH}" | head "-${KEEP_ONLY}" | jq -r '.key'); do
      echo "[INFO] Removing \`${object}\`"
      echo -n '[INFO] '
      mc rm -r --force "${MC_FLAGS[@]}" -r "${object}"
      [[ $? != 0 ]] && echo "[WARN] Cannot delete object ${object}"
    done
  fi
  echo "[INFO] Removing complete"
fi

echo "[INFO] $(date -u)"
