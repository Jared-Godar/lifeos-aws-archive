#!/usr/bin/env bash
set -euo pipefail

BUCKET="${BUCKET:-lifeos-archive-example}"
SOURCE_DIR="${SOURCE_DIR:-$HOME/Movies/GoPro}"
DEST="s3://${BUCKET}/video/gopro/"
LOG_DIR="logs"
TOTAL_EXPECTED_FILES="${TOTAL_EXPECTED_FILES:-63}"

mkdir -p "$LOG_DIR"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

print_header() {
  echo
  echo "========================================"
  echo "$1"
  echo "========================================"
}

print_header "LifeOS GoPro Upload Resume"
echo "Timestamp: $(timestamp)"
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST"
echo "Log directory: $LOG_DIR"
echo "Expected file count: $TOTAL_EXPECTED_FILES"

print_header "Preflight Checks"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Source directory does not exist: $SOURCE_DIR"
  exit 1
fi

echo "Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS credentials are invalid or expired."
  echo "Run aws login, then rerun this script."
  exit 1
fi
echo "AWS credentials valid."

echo "Checking bucket access..."
if ! aws s3 ls "s3://${BUCKET}/" >/dev/null 2>&1; then
  echo "ERROR: Cannot access bucket: $BUCKET"
  exit 1
fi
echo "Bucket access confirmed."

LOCAL_FILES="$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')"
LOCAL_SIZE="$(du -sh "$SOURCE_DIR" | awk '{print $1}')"

echo "Local files: $LOCAL_FILES"
echo "Local size:  $LOCAL_SIZE"

print_header "Current Remote Status"
aws s3 ls "$DEST" --recursive --summarize | tail -2 || true

REMOTE_FILES_BEFORE="$(aws s3 ls "$DEST" --recursive | wc -l | tr -d ' ' || echo 0)"
REMOTE_BYTES_BEFORE="$(aws s3 ls "$DEST" --recursive --summarize | awk '/Total Size/ {print $3}' || echo 0)"

echo "Remote files before sync: $REMOTE_FILES_BEFORE"
echo "Remote bytes before sync: $REMOTE_BYTES_BEFORE"

print_header "Dry Run - Remaining Uploads"
aws s3 sync "$SOURCE_DIR" "$DEST" --dryrun || {
  echo "ERROR: Dry run failed."
  exit 1
}

print_header "Starting / Resuming Upload"
LOG_FILE="$LOG_DIR/gopro_sync_$(date +%Y%m%d_%H%M%S).log"
echo "Logging to: $LOG_FILE"

aws s3 sync "$SOURCE_DIR" "$DEST" --no-progress 2>&1 | tee "$LOG_FILE"

print_header "Post-Upload Remote Status"
aws s3 ls "$DEST" --recursive --summarize | tail -2

REMOTE_FILES_AFTER="$(aws s3 ls "$DEST" --recursive | wc -l | tr -d ' ')"
REMOTE_BYTES_AFTER="$(aws s3 ls "$DEST" --recursive --summarize | awk '/Total Size/ {print $3}')"

echo "Remote files after sync: $REMOTE_FILES_AFTER"
echo "Remote bytes after sync: $REMOTE_BYTES_AFTER"

print_header "Verification Summary"
echo "Local files:  $LOCAL_FILES"
echo "Remote files: $REMOTE_FILES_AFTER"

if [[ "$LOCAL_FILES" == "$REMOTE_FILES_AFTER" ]]; then
  echo "PASS: Local and remote file counts match."
else
  echo "WARNING: Local and remote file counts do not match."
fi

if [[ "$REMOTE_FILES_AFTER" == "$TOTAL_EXPECTED_FILES" ]]; then
  echo "PASS: Remote file count matches expected count."
else
  echo "WARNING: Remote file count does not match expected count."
fi

print_header "Final Dry Run Check"
FINAL_DRYRUN="$(aws s3 sync "$SOURCE_DIR" "$DEST" --dryrun)"

if [[ -z "$FINAL_DRYRUN" ]]; then
  echo "PASS: Final dry run shows no remaining uploads."
else
  echo "WARNING: Final dry run found remaining upload actions:"
  echo "$FINAL_DRYRUN"
fi

print_header "Complete"
echo "Timestamp: $(timestamp)"
echo "Resume script complete."
