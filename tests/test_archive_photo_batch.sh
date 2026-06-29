#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$REPO_ROOT/scripts/archive_photo_batch.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

SOURCE_PARENT="$TMP_ROOT/photo-exports"
SOURCE_DIR="$SOURCE_PARENT/Family Photos"
STANDARD_DIR="$SOURCE_PARENT/2025-family"
MOCK_BIN="$TMP_ROOT/bin"
MOCK_SCRIPTS="$TMP_ROOT/scripts"
RECORD_DIR="$TMP_ROOT/records"
RESTORE_ROOT="$TMP_ROOT/restores"
MANIFEST_DIR="$TMP_ROOT/manifests"
CALL_LOG="$TMP_ROOT/calls.log"
OUTPUT_LOG="$TMP_ROOT/output.log"

mkdir -p "$SOURCE_DIR" "$MOCK_BIN" "$MOCK_SCRIPTS"
printf 'xmp metadata\n' > "$SOURCE_DIR/photo.xmp"
printf 'fake jpeg bytes\n' > "$SOURCE_DIR/photo.jpg"

REMOTE_BYTES="$(( $(stat -f '%z' "$SOURCE_DIR/photo.xmp") + $(stat -f '%z' "$SOURCE_DIR/photo.jpg") ))"

cat > "$MOCK_BIN/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1 $2" == "s3 ls" ]]; then
  echo "Total Objects: 2"
  echo "   Total Size: $MOCK_REMOTE_BYTES"
elif [[ "$1 $2" == "s3 sync" ]]; then
  exit 0
elif [[ "$1 $2" == "s3 cp" ]]; then
  source_uri="$3"
  destination="$4"
  relative_path="${source_uri#s3://test-bucket/photos/ingest/2025-family/}"
  cp "$MOCK_STANDARD_DIR/$relative_path" "$destination"
else
  echo "Unexpected mock AWS call: $*" >&2
  exit 1
fi
EOF

cat > "$MOCK_BIN/mock-open" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'open %s\n' "$*" >> "$MOCK_CALL_LOG"
[[ -f "$1" && -f "$2" ]]
EOF

cat > "$MOCK_SCRIPTS/sync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sync %s %s %s\n' "${DEST_PREFIX:?}" "${EXPECTED_FILES:?}" "$*" >> "$MOCK_CALL_LOG"
EOF

cat > "$MOCK_SCRIPTS/generate" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$2"
printf './photo.jpg\n./photo.xmp\n' > "$2/${3}_file_list_test.txt"
printf 'hash  ./photo.jpg\nhash  ./photo.xmp\n' > "$2/${3}_sha256_test.txt"
printf 'generate %s %s\n' "$1" "$3" >> "$MOCK_CALL_LOG"
EOF

cat > "$MOCK_SCRIPTS/upload" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'manifest %s %s %s\n' "${COLLECTION:?}" "${DEST_PREFIX:?}" "$*" >> "$MOCK_CALL_LOG"
EOF

chmod +x "$MOCK_BIN/aws" "$MOCK_BIN/mock-open" "$MOCK_SCRIPTS/"*

printf 'y\ny\ny\n' |
  PATH="$MOCK_BIN:$PATH" \
  BUCKET="test-bucket" \
  SYNC_SCRIPT="$MOCK_SCRIPTS/sync" \
  GENERATE_MANIFEST_SCRIPT="$MOCK_SCRIPTS/generate" \
  UPLOAD_MANIFEST_SCRIPT="$MOCK_SCRIPTS/upload" \
  OPEN_COMMAND="mock-open" \
  MANIFEST_DIR="$MANIFEST_DIR" \
  RECORD_DIR="$RECORD_DIR" \
  RESTORE_ROOT="$RESTORE_ROOT" \
  MOCK_REMOTE_BYTES="$REMOTE_BYTES" \
  MOCK_STANDARD_DIR="$STANDARD_DIR" \
  MOCK_CALL_LOG="$CALL_LOG" \
  "$SCRIPT" \
    --source "$SOURCE_DIR" \
    --label 2025-family \
    --cooloff-days 7 > "$OUTPUT_LOG"

[[ -d "$STANDARD_DIR" ]]
[[ ! -e "$SOURCE_DIR" ]]
grep -q 'PASS: Counts, bytes, and final dry run reconcile.' "$OUTPUT_LOG"
grep -q 'PASS: XMP restored sample matches the local SHA-256.' "$OUTPUT_LOG"
grep -q 'PASS: Media restored sample matches the local SHA-256.' "$OUTPUT_LOG"
grep -q 'Production Photo Batch Complete' "$OUTPUT_LOG"
grep -q 'sync photos/ingest/2025-family 2 --no-progress' "$CALL_LOG"
grep -q 'sync photos/ingest/2025-family 2 --execute --no-progress' "$CALL_LOG"
grep -q 'manifest photos-2025-family manifests/photos-2025-family $' "$CALL_LOG"
grep -q 'manifest photos-2025-family manifests/photos-2025-family --execute' "$CALL_LOG"
grep -q '^BEGIN:VCALENDAR' "$RECORD_DIR/2025-family_cooloff_review.ics"
grep -q 'SUMMARY:Review archived photo batch: 2025-family' "$RECORD_DIR/2025-family_cooloff_review.ics"
grep -q 'Visual comparison: passed' "$RECORD_DIR/2025-family_verification_"*.md

echo "PASS: production photo helper completed the mocked end-to-end workflow."
