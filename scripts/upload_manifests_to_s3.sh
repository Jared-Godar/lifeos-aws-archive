#!/usr/bin/env bash
set -euo pipefail

# LifeOS Manifest S3 Upload
#
# Uploads one collection's generated manifests to its S3 prefix.
# The default mode is a dry run; pass --execute to upload files.
#
# Usage:
#   scripts/upload_manifests_to_s3.sh
#   scripts/upload_manifests_to_s3.sh --execute
#   COLLECTION=photos scripts/upload_manifests_to_s3.sh --execute
#   BUCKET=alternate-bucket COLLECTION=gopro scripts/upload_manifests_to_s3.sh
#
# Optional environment overrides:
#   BUCKET="your-bucket-name"
#   COLLECTION="gopro"
#   MANIFEST_DIR="/path/to/manifests"
#   DEST_PREFIX="manifests/gopro"
#   ENV_FILE="/path/to/.env.private"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

COLLECTION="${COLLECTION:-gopro}"
MANIFEST_DIR="${MANIFEST_DIR:-$REPO_ROOT/manifests}"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env.private}"
EXECUTE=false

usage() {
  sed -n '4,20p' "$0"
}

for arg in "$@"; do
  case "$arg" in
    --execute)
      EXECUTE=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $arg"
      echo "Use --help for usage."
      exit 1
      ;;
  esac
done

if [[ ! "$COLLECTION" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "ERROR: Invalid collection name: $COLLECTION"
  echo "Use lowercase letters, numbers, dots, underscores, or hyphens."
  exit 1
fi

if [[ -z "${BUCKET:-}" && -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

BUCKET="${BUCKET:-${BUCKET_NAME:-}}"

if [[ -z "$BUCKET" ]]; then
  echo "ERROR: No destination bucket configured."
  echo "Set BUCKET or define BUCKET_NAME in: $ENV_FILE"
  exit 1
fi

DEST_PREFIX="${DEST_PREFIX:-manifests/$COLLECTION}"
DEST="s3://${BUCKET}/${DEST_PREFIX%/}/"
LOCK_DIR="/tmp/lifeos_manifest_upload_${COLLECTION}.lock"
INCLUDE_PATTERN="${COLLECTION}_*.txt"
SYNC_FILTERS=(
  --exclude "*"
  --include "$INCLUDE_PATTERN"
  --exclude "*.gitkeep"
)

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

section() {
  echo
  echo "========================================"
  echo "$1"
  echo "========================================"
}

cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

section "LifeOS Manifest S3 Upload"
echo "Timestamp:    $(timestamp)"
echo "Mode:         $([[ "$EXECUTE" == true ]] && echo "EXECUTE" || echo "DRY RUN")"
echo "Collection:   $COLLECTION"
echo "Source:       $MANIFEST_DIR"
echo "Destination:  $DEST"
echo "File pattern: $INCLUDE_PATTERN"

section "Preflight Checks"

if [[ ! -d "$MANIFEST_DIR" ]]; then
  echo "ERROR: Manifest directory does not exist: $MANIFEST_DIR"
  exit 1
fi

MATCHING_FILES=()
while IFS= read -r -d '' file; do
  MATCHING_FILES+=("$file")
done < <(find "$MANIFEST_DIR" -maxdepth 1 -type f -name "$INCLUDE_PATTERN" -print0 | LC_ALL=C sort -z)

if [[ "${#MATCHING_FILES[@]}" -eq 0 ]]; then
  echo "ERROR: No manifests match $INCLUDE_PATTERN in $MANIFEST_DIR"
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not installed or not on PATH."
  exit 1
fi

echo "Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS credentials are invalid or expired."
  exit 1
fi
echo "AWS credentials valid."

echo "Checking S3 bucket access..."
if ! aws s3 ls "s3://${BUCKET}/" >/dev/null 2>&1; then
  echo "ERROR: Cannot access bucket: $BUCKET"
  exit 1
fi
echo "Bucket access confirmed."

echo "Matching manifests: ${#MATCHING_FILES[@]}"
printf '  %s\n' "${MATCHING_FILES[@]}"

section "Dry Run"
aws s3 sync "$MANIFEST_DIR/" "$DEST" "${SYNC_FILTERS[@]}" --dryrun

if [[ "$EXECUTE" != true ]]; then
  section "Dry Run Complete"
  echo "No files were uploaded."
  echo "Run with --execute to upload the manifests."
  exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "ERROR: Upload lock exists: $LOCK_DIR"
  echo "Remove it only after confirming no manifest upload is active."
  exit 1
fi
trap cleanup EXIT

section "Starting Upload"
aws s3 sync \
  "$MANIFEST_DIR/" \
  "$DEST" \
  "${SYNC_FILTERS[@]}" \
  --checksum-algorithm SHA256 \
  --no-progress

section "Final Verification"
FINAL_DRYRUN="$(aws s3 sync "$MANIFEST_DIR/" "$DEST" "${SYNC_FILTERS[@]}" --dryrun)"

if [[ -n "$FINAL_DRYRUN" ]]; then
  echo "FAIL: Final dry run found remaining upload actions:"
  echo "$FINAL_DRYRUN"
  exit 1
fi

echo "PASS: Final dry run shows no remaining uploads."
aws s3 ls "$DEST" --recursive --summarize | tail -2

section "Complete"
echo "Timestamp:   $(timestamp)"
echo "Collection:  $COLLECTION"
echo "Destination: $DEST"
