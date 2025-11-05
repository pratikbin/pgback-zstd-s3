#!/bin/bash -e

WAIT_TIME=30 #seconds
MC_FLAGS=()
MC_FLAGS+=(${MC_GLOBAL_FLAGS})
OBEJCT_PREFIX=${BACKUP_PREFIX:-$CLUSTER_NAME}
if [[ ! -z "$DEBUG" ]]; then
  set -x
fi

echo "[INFO] $(date -u)"

TIMESTAMP="$(date +"%Y_%m_%dT%H_%M_%S")"
S3_BUCKET_PATH="s3/${S3_BUCKET}/${S3_PREFIX/'/'}"
S3_URI_BASE="${S3_BUCKET_PATH}/${CLUSTER_NAME}/${OBEJCT_PREFIX}_${TIMESTAMP}.tar.zst"
# resources=("deployments")
resources=("statefulsets" "deployments" "cronjobs" "secrets" "configmaps" "services" "ingresses" "networkpolicy")

echo "[INFO] Creating backup of ${CLUSTER_NAME} cluster..."

mkdir -p $TIMESTAMP
cd $TIMESTAMP

# Get all namespaces
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

# Define a function for backing up a resource
backup_resource() {
  local ns=$1
  local resource=$2
  local item=$3

  # Create a directory for the resource type
  mkdir -p "$ns/$resource"

  # Backup the item
  kubectl get "$resource" "$item" -n "$ns" -o yaml >"$ns/$resource/$item.yaml"
}
export -f backup_resource

# Loop through each namespace
for ns in $namespaces; do
  # Create a directory for the namespace
  mkdir -p "$ns"

  # Loop through each resource
  for resource in "${resources[@]}"; do
    # Get all resources of this type in the namespace
    kubectl get "$resource" -n "$ns" --chunk-size=50 -o json | jq -r '.items[] | .metadata.name' | while read -r item; do
      # Backup each item
      backup_resource "$ns" "$resource" "$item"
      sleep 0.1
    done
  done
done

tar -c -I 'zstd -15 -T0' -f - ../$TIMESTAMP | mc pipe ${MC_FLAGS[@]} ${MC_UPLOAD_FLAGS} "${S3_URI_BASE}"

echo "[INFO] Backup complete"
echo "[INFO] Backup stats"
mc ls --json ${MC_FLAGS[@]/'--json'} "${S3_URI_BASE}" | jq

if [[ -n "$KEEP_LAST_BACKUPS" ]]; then
  echo "[INFO] Removing old backups"
  EXISTING_OBJECTS=$(mc find --name "${OBEJCT_PREFIX}*" ${MC_FLAGS[@]} $S3_BUCKET_PATH | wc -l)
  KEEP_ONLY="$(( ${EXISTING_OBJECTS} - ${KEEP_LAST_BACKUPS} ))"
  if [[ "${KEEP_ONLY}" -le 0 ]]; then
    echo "[INFO] There is nothing to remove"
  else
    export IFS=$'\n'
    for object in $(mc find --name "${OBEJCT_PREFIX}*" ${MC_FLAGS[@]/'--json'} --json "${S3_BUCKET_PATH}" | head "-${KEEP_ONLY}" | jq -r '.key'); do
      echo "[INFO] Removing ${object}"
      echo -n '[INFO] '
      mc rm -r --force ${MC_FLAGS[@]} -r "${object}"
      [[ $? != 0 ]] && echo "[WARN] Cannot delete object"
    done
  fi
  echo "[INFO] Removing complete"
fi

echo "[INFO] $(date -u)"
