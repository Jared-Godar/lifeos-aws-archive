#!/usr/bin/env bash
set -euo pipefail

# LifeOS GoPro S3 Sync
#
# Purpose:
#   Upload the local GoPro archive to the LifeOS S3 archive bucket.
#
# Default behavior:
#   - Validates AWS credentials
#   - Validates source directory
#   - Validates bucket access
#   - Shows local and remote status
#   - Performs a dry run unless --execute is passed
#   - Logs real uploads
#   - Performs post-upload verification
#
# Usage:
#   scripts/sync_gopro_to_s3.sh
#   scripts/sync_gopro_to_s3.sh --execute
#   scripts/sync_gopro_to_s3.sh --execute --no-progress
#
# Optional environment overrides:
#   BUCKET="your-bucket-name"
#   SOURCE_DIR="$HOME/Movies/GoPro"
#   DEST_PREFIX="video/gopro"
#   EXPECTED_FILES="63"

BUCKET="${BUCKET:-lifeos-archive-example}"
SOURCE_DIR="${SOURCE_DIR:-$HOME/Movies/GoPro}"
DEST_PREFIX="${DEST_PREFIX:-video/gopro}"
EXPECTED_FILES="${EXPECTED_FILES:-63}"
LOG_DIR="${LOG_DIR:-logs}"

EXECUTE=false
SHOW_PROGRESS=true

for arg in "$@"; do
  case "$arg" in
    --execute)
      EXECUTE=true
      ;;
    --no-progress)
      SHOW_PROGRESS=false
      ;;
    --help|-h)
      sed -n '1,35p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $arg"
      echo "Use --help for usage."
      exit 1
      ;;
  esac
done

DEST="s3://${BUCKET}/${DEST_PREFIX%/}/"
LOCK_FILE="/tmp/lifeos_gopro_s3_sync.lock"

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
  rm -f "$LOCK_FILE"
}

trap cleanup EXIT

section "LifeOS GoPro S3 Sync"
echo "Timestamp:      $(timestamp)"
echo "Mode:           $([[ "$EXECUTE" == true ]] && echo "EXECUTE" || echo "DRY RUN")"
echo "Source:         $SOURCE_DIR"
echo "Destination:    $DEST"
echo "Expected files: $EXPECTED_FILES"
echo "Log directory:  $LOG_DIR"

section "Preflight Checks"

if [[ -e "$LOCK_FILE" ]]; then
  echo "ERROR: Lock file exists: $LOCK_FILE"
  echo "Another sync may already be running."
  echo "If you are certain no sync is active, remove it:"
  echo "  rm -f $LOCK_FILE"
  exit 1
fi

touch "$LOCK_FILE"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Source directory does not exist:"
  echo "$SOURCE_DIR"
  exit 1
fi

mkdir -p "$LOG_DIR"

echo "Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS credentials are invalid or expired."
  echo "Run:"
  echo "  aws login"
  echo "Then rerun this script."
  exit 1
fi
echo "AWS credentials valid."

echo "Checking S3 bucket access..."
if ! aws s3 ls "s3://${BUCKET}/" >/dev/null 2>&1; then
  echo "ERROR: Cannot access bucket:"
  echo "$BUCKET"
  exit 1
fi
echo "Bucket access confirmed."

LOCAL_FILES="$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')"
LOCAL_SIZE="$(du -sh "$SOURCE_DIR" | awk '{print $1}')"

echo "Local files: $LOCAL_FILES"
echo "Local size:  $LOCAL_SIZE"

if [[ "$LOCAL_FILES" != "$EXPECTED_FILES" ]]; then
  echo "WARNING: Local file count does not match expected count."
  echo "Expected: $EXPECTED_FILES"
  echo "Found:    $LOCAL_FILES"
fi

section "Current Remote Status"

aws s3 ls "$DEST" --recursive --summarize | tail -2 || true

REMOTE_FILES_BEFORE="$(aws s3 ls "$DEST" --recursive | wc -l | tr -d ' ' || echo 0)"
REMOTE_BYTES_BEFORE="$(aws s3 ls "$DEST" --recursive --summarize | awk '/Total Size/ {print $3}' || echo 0)"

echo "Remote files before sync: $REMOTE_FILES_BEFORE"
echo "Remote bytes before sync: $REMOTE_BYTES_BEFORE"

section "Dry Run"

DRYRUN_OUTPUT="$(aws s3 sync "$SOURCE_DIR" "$DEST" --dryrun)"

if [[ -z "$DRYRUN_OUTPUT" ]]; then
  echo "Dry run found no remaining uploads."
else
  echo "$DRYRUN_OUTPUT"
fi

if [[ "$EXECUTE" != true ]]; then
  section "Dry Run Complete"
  echo "No files were uploaded."
  echo
  echo "To perform the real upload, run:"
  echo "  scripts/sync_gopro_to_s3.sh --execute"
  exit 0
fi

section "Starting Upload"

LOG_FILE="$LOG_DIR/gopro_sync_$(date +%Y%m%d_%H%M%S).log"
echo "Logging to: $LOG_FILE"

if [[ "$SHOW_PROGRESS" == true ]]; then
  aws s3 sync "$SOURCE_DIR" "$DEST" 2>&1 | tee "$LOG_FILE"
else
  aws s3 sync "$SOURCE_DIR" "$DEST" --no-progress 2>&1 | tee "$LOG_FILE"
fi

section "Post-Upload Remote Status"

aws s3 ls "$DEST" --recursive --summarize | tail -2

REMOTE_FILES_AFTER="$(aws s3 ls "$DEST" --recursive | wc -l | tr -d ' ')"
REMOTE_BYTES_AFTER="$(aws s3 ls "$DEST" --recursive --summarize | awk '/Total Size/ {print $3}')"

echo "Remote files after sync: $REMOTE_FILES_AFTER"
echo "Remote bytes after sync: $REMOTE_BYTES_AFTER"

section "Final Dry Run Verification"

FINAL_DRYRUN="$(aws s3 sync "$SOURCE_DIR" "$DEST" --dryrun)"

if [[ -z "$FINAL_DRYRUN" ]]; then
  echo "PASS: Final dry run shows no remaining uploads."
else
  echo "WARNING: Final dry run found remaining upload actions:"
  echo "$FINAL_DRYRUN"
fi

section "File Count Verification"

echo "Local files:  $LOCAL_FILES"
echo "Remote files: $REMOTE_FILES_AFTER"

if [[ "$LOCAL_FILES" == "$REMOTE_FILES_AFTER" ]]; then
  echo "PASS: Local and remote file counts match."
else
  echo "WARNING: Local and remote file counts do not match."
fi

if [[ "$REMOTE_FILES_AFTER" == "$EXPECTED_FILES" ]]; then
  echo "PASS: Remote file count matches expected count."
else
  echo "WARNING: Remote file count does not match expected count."
fi

section "Complete"

echo "Timestamp: $(timestamp)"
echo "Destination: $DEST"
echo "Log file: $LOG_FILE"
echo
echo "Next recommended validation:"
echo "  aws s3 sync \"$SOURCE_DIR\" \"$DEST\" --dryrun"
echo "  aws s3 ls \"$DEST\" --recursive --summarize | tail -2"
echo
echo "Do not delete local files until restore and checksum validation are complete."
