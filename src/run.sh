#!/bin/bash -e
env
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
checkCommandExist kubectl

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

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "[WARN] env CLUSTER_NAME not found"
  exit 1
fi

echo "[INFO] Using zstd compression level: ${ZSTD_COMPRESSION_LEVE:-15}"

if [[ -n "${S3_ENDPOINT}" ]]; then
  mc alias set ${MC_FLAGS[@]} "s3" "${S3_ENDPOINT}" "${S3_ACCESS_KEY_ID}" "${S3_SECRET_ACCESS_KEY}"
else
  mc alias set ${MC_FLAGS[@]} "s3" "https://s3.amazonaws.com" "${S3_ACCESS_KEY_ID}" "${S3_SECRET_ACCESS_KEY}"
fi

echo -n "[INFO] Starting "
exec /backup.sh
