#!/usr/bin/env bash
set -euo pipefail

# LifeOS GoPro S3 Verification
#
# Verifies that the local GoPro source and remote S3 archive agree.
#
# Checks:
#   - AWS credentials
#   - Source directory exists
#   - Bucket/prefix accessible
#   - Local file count
#   - Remote object count
#   - Final dry-run sync status
#   - Optional restore and SHA-256 integrity test
#
# Usage:
#   scripts/verify_gopro_sync.sh
#   scripts/verify_gopro_sync.sh --restore-sample
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
RESTORE_DIR="${RESTORE_DIR:-restore-tests}"
DEST="s3://${BUCKET}/${DEST_PREFIX%/}/"

RESTORE_SAMPLE=false

for arg in "$@"; do
  case "$arg" in
    --restore-sample)
      RESTORE_SAMPLE=true
      ;;
    --help|-h)
      sed -n '1,32p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $arg"
      echo "Use --help for usage."
      exit 1
      ;;
  esac
done

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

section() {
  echo
  echo "========================================"
  echo "$1"
  echo "========================================"
}

section "LifeOS GoPro S3 Verification"
echo "Timestamp:      $(timestamp)"
echo "Source:         $SOURCE_DIR"
echo "Destination:    $DEST"
echo "Expected files: $EXPECTED_FILES"

section "Preflight Checks"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Source directory does not exist:"
  echo "$SOURCE_DIR"
  exit 1
fi

echo "Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS credentials are invalid or expired."
  echo "Run aws login, then rerun this script."
  exit 1
fi
echo "AWS credentials valid."

echo "Checking S3 destination..."
if ! aws s3 ls "$DEST" >/dev/null 2>&1; then
  echo "ERROR: Cannot access S3 destination:"
  echo "$DEST"
  exit 1
fi
echo "S3 destination accessible."

section "Local Inventory"

LOCAL_FILES="$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')"
LOCAL_SIZE="$(du -sh "$SOURCE_DIR" | awk '{print $1}')"

echo "Local files: $LOCAL_FILES"
echo "Local size:  $LOCAL_SIZE"

section "Remote Inventory"

aws s3 ls "$DEST" --recursive --summarize | tail -2

REMOTE_FILES="$(aws s3 ls "$DEST" --recursive | wc -l | tr -d ' ')"
REMOTE_BYTES="$(aws s3 ls "$DEST" --recursive --summarize | awk '/Total Size/ {print $3}')"
REMOTE_GIB="$(awk -v bytes="$REMOTE_BYTES" 'BEGIN { printf "%.2f", bytes / 1024 / 1024 / 1024 }')"

echo "Remote files: $REMOTE_FILES"
echo "Remote bytes: $REMOTE_BYTES"
echo "Remote GiB:   $REMOTE_GIB"

section "File Count Verification"

if [[ "$LOCAL_FILES" == "$REMOTE_FILES" ]]; then
  echo "PASS: Local and remote file counts match."
else
  echo "FAIL: Local and remote file counts do not match."
  echo "Local:  $LOCAL_FILES"
  echo "Remote: $REMOTE_FILES"
  exit 1
fi

if [[ "$REMOTE_FILES" == "$EXPECTED_FILES" ]]; then
  echo "PASS: Remote file count matches expected count."
else
  echo "FAIL: Remote file count does not match expected count."
  echo "Expected: $EXPECTED_FILES"
  echo "Remote:   $REMOTE_FILES"
  exit 1
fi

section "Final Dry Run Verification"

FINAL_DRYRUN="$(aws s3 sync "$SOURCE_DIR" "$DEST" --dryrun)"

if [[ -z "$FINAL_DRYRUN" ]]; then
  echo "PASS: Dry run shows no remaining uploads."
else
  echo "FAIL: Dry run found remaining upload actions:"
  echo "$FINAL_DRYRUN"
  exit 1
fi

section "Remote Object Sample"

aws s3 ls "$DEST" --recursive > /tmp/gopro_remote_objects.txt
head -5 /tmp/gopro_remote_objects.txt
echo "..."
tail -5 /tmp/gopro_remote_objects.txt

if [[ "$RESTORE_SAMPLE" == true ]]; then
  section "Restore Sample Test"

  mkdir -p "$RESTORE_DIR"

  SAMPLE_KEY="$(
    aws s3api list-objects-v2 \
      --bucket "$BUCKET" \
      --prefix "${DEST_PREFIX%/}/" \
      --query 'sort_by(Contents, &Size)[0].Key' \
      --output text
  )"

  if [[ -z "$SAMPLE_KEY" || "$SAMPLE_KEY" == "None" ]]; then
    echo "FAIL: Could not identify sample object."
    exit 1
  fi

  SAMPLE_NAME="$(basename "$SAMPLE_KEY")"
  RESTORE_PATH="$RESTORE_DIR/$SAMPLE_NAME"

  echo "Sample key:  $SAMPLE_KEY"
  echo "Restore to:   $RESTORE_PATH"

  LOCAL_SAMPLE_RELATIVE="${SAMPLE_KEY#"${DEST_PREFIX%/}"/}"
  LOCAL_SAMPLE_PATH="$SOURCE_DIR/$LOCAL_SAMPLE_RELATIVE"

  if [[ ! -f "$LOCAL_SAMPLE_PATH" ]]; then
    echo "FAIL: Matching local sample does not exist:"
    echo "$LOCAL_SAMPLE_PATH"
    exit 1
  fi

  aws s3 cp \
    "s3://${BUCKET}/${SAMPLE_KEY}" \
    "$RESTORE_PATH" \
    --checksum-mode ENABLED

  if [[ -f "$RESTORE_PATH" ]]; then
    echo "PASS: Restore sample downloaded successfully."
    ls -lh "$RESTORE_PATH"
  else
    echo "FAIL: Restore sample was not downloaded."
    exit 1
  fi

  LOCAL_SHA256="$(shasum -a 256 "$LOCAL_SAMPLE_PATH" | awk '{print $1}')"
  RESTORED_SHA256="$(shasum -a 256 "$RESTORE_PATH" | awk '{print $1}')"

  echo "Local SHA-256:    $LOCAL_SHA256"
  echo "Restored SHA-256: $RESTORED_SHA256"

  if [[ "$LOCAL_SHA256" == "$RESTORED_SHA256" ]]; then
    echo "PASS: Restored sample matches the local SHA-256."
  else
    echo "FAIL: Restored sample does not match the local SHA-256."
    exit 1
  fi
else
  section "Restore Sample Skipped"
  echo "Run with --restore-sample before deleting local files."
fi

section "Verification Complete"

echo "Timestamp: $(timestamp)"
echo "PASS: GoPro local source and S3 archive are synchronized."
if [[ "$RESTORE_SAMPLE" == true ]]; then
  echo "PASS: Restored sample passed S3 and local SHA-256 validation."
else
  echo "NOTICE: Restore integrity was not tested."
fi
echo
echo "Do not delete local files until restore integrity validation is complete."
