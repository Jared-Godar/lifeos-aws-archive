#!/usr/bin/env bash
set -euo pipefail

# LifeOS Production Photo Batch Archive
#
# Selects and standardizes an exported photo folder, previews and executes its
# guarded S3 upload, reconciles local and remote inventory, restores and checks
# both XMP and media samples, uploads manifests, records verification evidence,
# and creates an iCalendar reminder for the local-deletion cooling-off review.
#
# Usage:
#   scripts/archive_photo_batch.sh
#   scripts/archive_photo_batch.sh --source "/path/to/exported photos"
#   scripts/archive_photo_batch.sh --source DIR --label 2025-family
#   scripts/archive_photo_batch.sh --cooloff-days 7
#   scripts/archive_photo_batch.sh --source DIR --label 2025-family --resume
#
# Configuration:
#   BUCKET                  S3 bucket override
#   ENV_FILE                File containing BUCKET_NAME (default: .env.private)
#   MANIFEST_DIR            Local manifest directory (default: manifests/)
#   RECORD_DIR              Private records and ICS directory (default: logs/photo-batches/)
#   RESTORE_ROOT            Restored-sample root (default: restore-tests/photos/)
#   OPEN_COMMAND            macOS open command override, primarily for testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

SYNC_SCRIPT="${SYNC_SCRIPT:-$SCRIPT_DIR/sync_gopro_to_s3.sh}"
GENERATE_MANIFEST_SCRIPT="${GENERATE_MANIFEST_SCRIPT:-$SCRIPT_DIR/generate_manifest.sh}"
UPLOAD_MANIFEST_SCRIPT="${UPLOAD_MANIFEST_SCRIPT:-$SCRIPT_DIR/upload_manifests_to_s3.sh}"

ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env.private}"
MANIFEST_DIR="${MANIFEST_DIR:-$REPO_ROOT/manifests}"
RECORD_DIR="${RECORD_DIR:-$REPO_ROOT/logs/photo-batches}"
RESTORE_ROOT="${RESTORE_ROOT:-$REPO_ROOT/restore-tests/photos}"
OPEN_COMMAND="${OPEN_COMMAND:-open}"
COOL_OFF_DAYS="${COOL_OFF_DAYS:-7}"

SOURCE_INPUT=""
BATCH_LABEL=""
RESUME=false
RESUME_AVAILABLE=false
RESUME_PRINTED=false
CURRENT_STAGE="startup"

usage() {
  sed -n '4,24p' "$0"
}

section() {
  echo
  echo "========================================"
  echo "$1"
  echo "========================================"
}

confirm() {
  local prompt="$1"
  local reply=""

  echo "$prompt"
  while true; do
    printf 'Return to this terminal, type y or n, then press Enter: '
    if ! IFS= read -r reply; then
      echo
      echo "INPUT CLOSED: The terminal input stream ended before confirmation."
      return 2
    fi

    case "$reply" in
      y|Y|yes|YES|Yes)
        return 0
        ;;
      n|N|no|NO|No|"")
        if [[ -z "$reply" ]]; then
          echo "No response entered. Type y or n, then press Enter."
        else
          return 1
        fi
        ;;
      *)
        echo "Unrecognized response '$reply'. Type y or n."
        ;;
    esac
  done
}

fish_double_quote() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  printf '"%s"' "$value"
}

print_resume_command() {
  echo "Resume safely with this fish command:"
  printf '  scripts/archive_photo_batch.sh \\\n    --source '
  fish_double_quote "$SOURCE_DIR"
  printf ' \\\n    --label %s \\\n    --cooloff-days %s \\\n    --resume\n' "$BATCH_LABEL" "$COOL_OFF_DAYS"
  echo
  echo "Resume mode reruns synchronization, reconciliation, and restores"
  echo "idempotently before continuing to manifests and the calendar reminder."
}

pause_workflow() {
  local reason="$1"

  RESUME_PRINTED=true
  section "Workflow Incomplete — Safe to Resume"
  echo "$reason"
  echo "Completed S3 objects are retained; this helper never rolls them back."
  echo "No local source files were deleted."
  echo
  print_resume_command
  exit 3
}

on_exit() {
  local status="$?"

  if (( status != 0 )) && [[ "$RESUME_AVAILABLE" == true && "$RESUME_PRINTED" == false ]]; then
    echo
    section "Workflow Stopped During: $CURRENT_STAGE"
    echo "The workflow did not reach final completion."
    echo
    print_resume_command
  fi
}

trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

normalize_label() {
  printf '%s' "$1" |
    LC_ALL=C tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

canonical_directory() {
  (
    cd "$1"
    pwd -P
  )
}

inventory_local() {
  LOCAL_FILES=0
  LOCAL_BYTES=0

  while IFS= read -r -d '' file; do
    LOCAL_FILES=$((LOCAL_FILES + 1))
    if file_bytes="$(stat -f '%z' "$file" 2>/dev/null)"; then
      :
    else
      file_bytes="$(stat -c '%s' "$file")"
    fi
    LOCAL_BYTES=$((LOCAL_BYTES + file_bytes))
  done < <(find "$SOURCE_DIR" -type f -print0)
}

inventory_remote() {
  local listing

  listing="$(aws s3 ls "$S3_DEST" --recursive --summarize)"
  printf '%s\n' "$listing" | tail -2

  REMOTE_FILES="$(printf '%s\n' "$listing" | awk '/Total Objects:/ {value=$3} END {print value+0}')"
  REMOTE_BYTES="$(printf '%s\n' "$listing" | awk '/Total Size:/ {value=$3} END {print value+0}')"
}

select_samples() {
  XMP_SAMPLE=""
  MEDIA_SAMPLE=""

  while IFS= read -r -d '' file; do
    XMP_SAMPLE="$file"
    break
  done < <(find "$SOURCE_DIR" -type f -iname '*.xmp' -print0 | LC_ALL=C sort -z)

  while IFS= read -r -d '' file; do
    MEDIA_SAMPLE="$file"
    break
  done < <(
    find "$SOURCE_DIR" -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \
      -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' \
      -o -iname '*.dng' -o -iname '*.gif' -o -iname '*.mov' \
      -o -iname '*.mp4' -o -iname '*.m4v' \) \
      -print0 | LC_ALL=C sort -z
  )
}

restore_and_verify() {
  local sample_type="$1"
  local local_path="$2"
  local relative_path="${local_path#"$SOURCE_DIR"/}"
  local sample_key="${PHOTO_PREFIX%/}/$relative_path"
  local restored_path="$RESTORE_DIR/$relative_path"
  local local_sha256
  local restored_sha256

  mkdir -p "$(dirname "$restored_path")"

  echo "$sample_type local:    $local_path"
  echo "$sample_type S3 key:   $sample_key"
  echo "$sample_type restore:  $restored_path"

  aws s3 cp \
    "s3://${BUCKET}/${sample_key}" \
    "$restored_path" \
    --checksum-mode ENABLED

  if [[ ! -f "$restored_path" ]]; then
    echo "FAIL: $sample_type sample was not restored."
    return 1
  fi

  local_sha256="$(shasum -a 256 -- "$local_path" | awk '{print $1}')"
  restored_sha256="$(shasum -a 256 -- "$restored_path" | awk '{print $1}')"

  echo "$sample_type local SHA-256:    $local_sha256"
  echo "$sample_type restored SHA-256: $restored_sha256"

  if [[ "$local_sha256" != "$restored_sha256" ]]; then
    echo "FAIL: $sample_type SHA-256 values do not match."
    return 1
  fi

  echo "PASS: $sample_type restored sample matches the local SHA-256."

  if [[ "$sample_type" == "XMP" ]]; then
    XMP_RELATIVE="$relative_path"
    XMP_LOCAL_SHA256="$local_sha256"
    XMP_RESTORED_SHA256="$restored_sha256"
    RESTORED_XMP="$restored_path"
  else
    MEDIA_RELATIVE="$relative_path"
    MEDIA_LOCAL_SHA256="$local_sha256"
    MEDIA_RESTORED_SHA256="$restored_sha256"
    RESTORED_MEDIA="$restored_path"
  fi
}

date_after_days() {
  local days="$1"

  if date -v+1d +%Y%m%d >/dev/null 2>&1; then
    date -v+"${days}"d +%Y%m%d
  else
    date -d "+${days} days" +%Y%m%d
  fi
}

create_calendar_file() {
  local review_date
  local end_date
  local dtstamp

  review_date="$(date_after_days "$COOL_OFF_DAYS")"
  end_date="$(date_after_days "$((COOL_OFF_DAYS + 1))")"
  dtstamp="$(date -u +%Y%m%dT%H%M%SZ)"
  ICS_FILE="$RECORD_DIR/${BATCH_LABEL}_cooloff_review.ics"

  {
    printf '%s\r\n' 'BEGIN:VCALENDAR'
    printf '%s\r\n' 'VERSION:2.0'
    printf '%s\r\n' 'PRODID:-//LifeOS//Photo Archive Cooloff//EN'
    printf '%s\r\n' 'CALSCALE:GREGORIAN'
    printf '%s\r\n' 'METHOD:PUBLISH'
    printf '%s\r\n' 'BEGIN:VEVENT'
    printf 'UID:photo-cooloff-%s-%s@lifeos.local\r\n' "$BATCH_LABEL" "$dtstamp"
    printf 'DTSTAMP:%s\r\n' "$dtstamp"
    printf 'DTSTART;VALUE=DATE:%s\r\n' "$review_date"
    printf 'DTEND;VALUE=DATE:%s\r\n' "$end_date"
    printf 'SUMMARY:Review archived photo batch: %s\r\n' "$BATCH_LABEL"
    printf 'DESCRIPTION:Cooling-off review for s3://%s/%s/. Do not delete local files unless archive verification and independent-copy requirements remain satisfied.\r\n' "$BUCKET" "$PHOTO_PREFIX"
    printf '%s\r\n' 'END:VEVENT'
    printf '%s\r\n' 'END:VCALENDAR'
  } > "$ICS_FILE"
}

write_verification_record() {
  RECORD_FILE="$RECORD_DIR/${BATCH_LABEL}_verification_${RUN_ID}.md"

  {
    echo "# Photo Batch Verification: $BATCH_LABEL"
    echo
    echo "- Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "- Local source: \`$SOURCE_DIR\`"
    echo "- S3 destination: \`$S3_DEST\`"
    echo "- Local files: $LOCAL_FILES"
    echo "- Local bytes: $LOCAL_BYTES"
    echo "- Remote files: $REMOTE_FILES"
    echo "- Remote bytes: $REMOTE_BYTES"
    echo "- XMP sample: \`$XMP_RELATIVE\`"
    echo "- XMP SHA-256: \`$XMP_LOCAL_SHA256\`"
    echo "- Restored XMP: \`$RESTORED_XMP\`"
    echo "- Restored XMP SHA-256: \`$XMP_RESTORED_SHA256\`"
    echo "- Media sample: \`$MEDIA_RELATIVE\`"
    echo "- Media SHA-256: \`$MEDIA_LOCAL_SHA256\`"
    echo "- Restored media: \`$RESTORED_MEDIA\`"
    echo "- Restored media SHA-256: \`$MEDIA_RESTORED_SHA256\`"
    echo "- Visual comparison: passed"
    echo "- Manifest collection: \`$MANIFEST_COLLECTION\`"
    echo "- Manifest destination: \`s3://${BUCKET}/${MANIFEST_PREFIX}/\`"
    echo "- Cooling-off period: $COOL_OFF_DAYS days"
    echo "- Calendar event: \`$ICS_FILE\`"
    echo
    echo "Do not treat this record as authorization to delete the only remaining local"
    echo "copy. Confirm the archive policy and independent-copy requirement first."
  } > "$RECORD_FILE"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --source)
      [[ "$#" -ge 2 ]] || { echo "ERROR: --source requires a directory."; exit 1; }
      SOURCE_INPUT="$2"
      shift 2
      ;;
    --label)
      [[ "$#" -ge 2 ]] || { echo "ERROR: --label requires a value."; exit 1; }
      BATCH_LABEL="$2"
      shift 2
      ;;
    --cooloff-days)
      [[ "$#" -ge 2 ]] || { echo "ERROR: --cooloff-days requires a number."; exit 1; }
      COOL_OFF_DAYS="$2"
      shift 2
      ;;
    --resume)
      RESUME=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      echo "Use --help for usage."
      exit 1
      ;;
  esac
done

if [[ ! "$COOL_OFF_DAYS" =~ ^[0-9]+$ ]] || (( COOL_OFF_DAYS < 1 || COOL_OFF_DAYS > 365 )); then
  echo "ERROR: Cooling-off days must be an integer from 1 through 365."
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

section "Select Production Photo Folder"

if [[ -z "$SOURCE_INPUT" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]] || ! command -v osascript >/dev/null 2>&1; then
    echo "ERROR: Automatic folder selection requires macOS."
    echo "Use --source /path/to/exported-photos."
    exit 1
  fi

  SOURCE_INPUT="$(osascript -e 'POSIX path of (choose folder with prompt "Select the exported production photo batch")')" || {
    echo "Folder selection cancelled."
    exit 0
  }
  SOURCE_INPUT="${SOURCE_INPUT%/}"
fi

if [[ ! -d "$SOURCE_INPUT" ]]; then
  echo "ERROR: Source directory does not exist: $SOURCE_INPUT"
  exit 1
fi

SOURCE_DIR="$(canonical_directory "$SOURCE_INPUT")"

if [[ "$SOURCE_DIR" == *.photoslibrary || "$SOURCE_DIR" == *.photoslibrary/* ]]; then
  echo "ERROR: Do not upload an Apple Photos library package directly."
  echo "Export unmodified originals and XMP sidecars to a normal folder first."
  exit 1
fi

SUGGESTED_LABEL="$(normalize_label "$(basename "$SOURCE_DIR")")"

if [[ -z "$BATCH_LABEL" ]]; then
  printf 'Batch label [%s]: ' "$SUGGESTED_LABEL"
  if ! IFS= read -r BATCH_LABEL; then
    echo
    echo "INPUT CLOSED: No batch label was received. No changes were made."
    echo "Rerun with --label $SUGGESTED_LABEL to avoid this prompt."
    exit 3
  fi
  BATCH_LABEL="${BATCH_LABEL:-$SUGGESTED_LABEL}"
fi

if [[ ! "$BATCH_LABEL" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: Invalid batch label: $BATCH_LABEL"
  echo "Use lowercase letters, numbers, and hyphens."
  exit 1
fi

STANDARD_DIR="$(dirname "$SOURCE_DIR")/$BATCH_LABEL"

if [[ "$SOURCE_DIR" != "$STANDARD_DIR" ]]; then
  echo "Selected folder:     $SOURCE_DIR"
  echo "Standardized folder: $STANDARD_DIR"

  if [[ -e "$STANDARD_DIR" ]]; then
    echo "ERROR: Standardized destination already exists: $STANDARD_DIR"
    exit 1
  fi

  if confirm "Rename the selected folder to '$BATCH_LABEL'?"; then
    :
  else
    confirmation_status="$?"
    if (( confirmation_status == 2 )); then
      echo "Folder rename was not confirmed. No changes were made."
      exit 3
    fi
    echo "Cancelled before changing the folder or uploading files."
    exit 0
  fi

  mv "$SOURCE_DIR" "$STANDARD_DIR"
  SOURCE_DIR="$(canonical_directory "$STANDARD_DIR")"
  echo "Folder renamed successfully."
fi

PHOTO_PREFIX="photos/ingest/$BATCH_LABEL"
MANIFEST_COLLECTION="photos-$BATCH_LABEL"
MANIFEST_PREFIX="manifests/$MANIFEST_COLLECTION"
S3_DEST="s3://${BUCKET}/${PHOTO_PREFIX}/"
RESTORE_DIR="$RESTORE_ROOT/$BATCH_LABEL"
RUN_ID="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$RECORD_DIR" "$RESTORE_DIR" "$MANIFEST_DIR"

inventory_local
select_samples

if (( LOCAL_FILES == 0 )); then
  echo "ERROR: Selected photo folder contains no files."
  exit 1
fi

if [[ -z "$XMP_SAMPLE" ]]; then
  echo "ERROR: No XMP sidecar was found."
  echo "Re-export the batch with 'Export IPTC as XMP' enabled."
  exit 1
fi

if [[ -z "$MEDIA_SAMPLE" ]]; then
  echo "ERROR: No supported photo or video sample was found."
  exit 1
fi

RESUME_AVAILABLE=true
PLANNED_LOCAL_FILES="$LOCAL_FILES"
PLANNED_LOCAL_BYTES="$LOCAL_BYTES"

section "Archive Plan"
echo "Local source:        $SOURCE_DIR"
echo "Local files:         $LOCAL_FILES"
echo "Local bytes:         $LOCAL_BYTES"
echo "S3 destination:      $S3_DEST"
echo "Manifest collection: $MANIFEST_COLLECTION"
echo "Manifest destination: s3://${BUCKET}/${MANIFEST_PREFIX}/"
echo "XMP sample:          ${XMP_SAMPLE#"$SOURCE_DIR"/}"
echo "Media sample:        ${MEDIA_SAMPLE#"$SOURCE_DIR"/}"
echo "Cooling-off period:  $COOL_OFF_DAYS days"

section "Upload Dry Run"
CURRENT_STAGE="upload dry run"
BUCKET="$BUCKET" \
SOURCE_DIR="$SOURCE_DIR" \
DEST_PREFIX="$PHOTO_PREFIX" \
EXPECTED_FILES="$LOCAL_FILES" \
LOG_DIR="$RECORD_DIR" \
  "$SYNC_SCRIPT" --no-progress

echo
echo "Review the dry-run output and archive plan above."
if [[ "$RESUME" == true ]]; then
  echo "RESUME MODE: Fresh approval is required because the source may have changed."
  echo "The checksum-backed sync transfers only missing or changed files."
fi

if confirm "Proceed with the production S3 upload shown above?"; then
  :
else
  confirmation_status="$?"
  if (( confirmation_status == 2 )); then
    pause_workflow "Upload authorization was not received because terminal input closed."
  fi
  echo "Upload cancelled by user. No upload was started at this checkpoint."
  exit 0
fi

inventory_local
if [[ "$LOCAL_FILES" != "$PLANNED_LOCAL_FILES" || "$LOCAL_BYTES" != "$PLANNED_LOCAL_BYTES" ]]; then
  pause_workflow "The local source changed after the archive plan was calculated. Planned: ${PLANNED_LOCAL_FILES} files / ${PLANNED_LOCAL_BYTES} bytes. Current: ${LOCAL_FILES} files / ${LOCAL_BYTES} bytes. Wait for the export to finish, then resume to review a fresh dry run."
fi

section "Production Upload"
CURRENT_STAGE="production upload"
BUCKET="$BUCKET" \
SOURCE_DIR="$SOURCE_DIR" \
DEST_PREFIX="$PHOTO_PREFIX" \
EXPECTED_FILES="$LOCAL_FILES" \
LOG_DIR="$RECORD_DIR" \
  "$SYNC_SCRIPT" --execute --no-progress

section "Independent Reconciliation"
CURRENT_STAGE="independent reconciliation"
inventory_remote
echo "Local files:  $LOCAL_FILES"
echo "Remote files: $REMOTE_FILES"
echo "Local bytes:  $LOCAL_BYTES"
echo "Remote bytes: $REMOTE_BYTES"

if [[ "$LOCAL_FILES" != "$REMOTE_FILES" ]]; then
  echo "FAIL: Local and remote file counts do not match."
  exit 1
fi

if [[ "$LOCAL_BYTES" != "$REMOTE_BYTES" ]]; then
  echo "FAIL: Local and remote byte totals do not match."
  exit 1
fi

FINAL_DRYRUN="$(aws s3 sync "$SOURCE_DIR" "$S3_DEST" --dryrun)"
if [[ -n "$FINAL_DRYRUN" ]]; then
  echo "FAIL: Final dry run found remaining upload actions:"
  echo "$FINAL_DRYRUN"
  exit 1
fi

echo "PASS: Counts, bytes, and final dry run reconcile."

section "Restore and SHA-256 Verification"
CURRENT_STAGE="restore and checksum verification"
restore_and_verify "XMP" "$XMP_SAMPLE"
echo
restore_and_verify "Media" "$MEDIA_SAMPLE"

section "Visual Media Comparison"
CURRENT_STAGE="visual media confirmation"
echo "Opening the original and restored media with their default macOS application."
"$OPEN_COMMAND" "$MEDIA_SAMPLE" "$RESTORED_MEDIA"

if confirm "VISUAL CHECK REQUIRED: Did both media files open successfully and match visually?"; then
  :
else
  confirmation_status="$?"
  if (( confirmation_status == 2 )); then
    pause_workflow "Upload, reconciliation, and both SHA-256 checks passed, but visual confirmation was not recorded because terminal input closed. Manifests and the cooling-off reminder were not created."
  fi
  pause_workflow "Upload, reconciliation, and both SHA-256 checks passed, but you answered no to the visual comparison. Manifests and the cooling-off reminder were not created."
fi

section "Generate Manifests"
CURRENT_STAGE="manifest generation"
"$GENERATE_MANIFEST_SCRIPT" "$SOURCE_DIR" "$MANIFEST_DIR" "$MANIFEST_COLLECTION"

section "Manifest Upload Dry Run"
CURRENT_STAGE="manifest upload dry run"
BUCKET="$BUCKET" \
COLLECTION="$MANIFEST_COLLECTION" \
MANIFEST_DIR="$MANIFEST_DIR" \
DEST_PREFIX="$MANIFEST_PREFIX" \
ENV_FILE="$ENV_FILE" \
  "$UPLOAD_MANIFEST_SCRIPT"

section "Manifest Upload"
CURRENT_STAGE="manifest upload"
BUCKET="$BUCKET" \
COLLECTION="$MANIFEST_COLLECTION" \
MANIFEST_DIR="$MANIFEST_DIR" \
DEST_PREFIX="$MANIFEST_PREFIX" \
ENV_FILE="$ENV_FILE" \
  "$UPLOAD_MANIFEST_SCRIPT" --execute

section "Verification Record and Cooling-Off Reminder"
CURRENT_STAGE="verification record and cooling-off reminder"
create_calendar_file
write_verification_record

echo "Verification record: $RECORD_FILE"
echo "Calendar event:      $ICS_FILE"
echo
echo "Opening the cooling-off reminder in the default calendar application."
if "$OPEN_COMMAND" "$ICS_FILE"; then
  echo "Calendar reminder opened successfully."
else
  echo "WARNING: The archive completed, but the calendar reminder did not open."
  echo "Open it manually: $ICS_FILE"
fi

section "Production Photo Batch Complete"
CURRENT_STAGE="complete"
echo "Batch:          $BATCH_LABEL"
echo "S3 destination: $S3_DEST"
echo "Files:          $LOCAL_FILES"
echo "Bytes:          $LOCAL_BYTES"
echo "XMP restore:    PASS"
echo "Media restore:  PASS"
echo "Visual check:   PASS"
echo "Manifests:      s3://${BUCKET}/${MANIFEST_PREFIX}/"
echo
echo "Do not delete local or Apple Photos originals during the cooling-off period."
