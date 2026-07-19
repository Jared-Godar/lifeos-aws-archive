#!/usr/bin/env bash
set -euo pipefail

# Verifies scripts/verify_gopro_sync.sh, the integrity gate consulted before
# deleting local originals. A false PASS from this script would destroy the
# only copy, so the failure paths matter more than the happy path: count
# mismatches, unreconciled dry runs, and restore-sample corruption must all
# fail loudly.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$REPO_ROOT/scripts/verify_gopro_sync.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

SOURCE_DIR="$TMP_ROOT/gopro"
MOCK_BIN="$TMP_ROOT/bin"
RESTORE_DIR="$TMP_ROOT/restores"
REMOTE_LIST_MATCHED="$TMP_ROOT/remote_matched.txt"
REMOTE_LIST_EXTRA="$TMP_ROOT/remote_extra.txt"
CORRUPT_SAMPLE="$TMP_ROOT/corrupt_clip.mp4"

mkdir -p "$SOURCE_DIR" "$MOCK_BIN"
printf 'first clip bytes\n' > "$SOURCE_DIR/clip_a.mp4"
printf 'second clip bytes\n' > "$SOURCE_DIR/clip_b.mp4"
printf 'corrupted clip bytes\n' > "$CORRUPT_SAMPLE"

cat > "$REMOTE_LIST_MATCHED" <<'EOF'
2026-07-19 10:00:00         17 video/gopro/clip_a.mp4
2026-07-19 10:00:01         18 video/gopro/clip_b.mp4
EOF

cat > "$REMOTE_LIST_EXTRA" <<'EOF'
2026-07-19 10:00:00         17 video/gopro/clip_a.mp4
2026-07-19 10:00:01         18 video/gopro/clip_b.mp4
2026-07-19 10:00:02         19 video/gopro/clip_c.mp4
EOF

cat > "$MOCK_BIN/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

args="$*"
if [[ "$1" == "sts" ]]; then
  echo '{"UserId": "mock-user"}'
elif [[ "$1 $2" == "s3 ls" && "$args" == *"--recursive"* && "$args" == *"--summarize"* ]]; then
  cat "$MOCK_REMOTE_LIST"
  echo "Total Objects: $(wc -l < "$MOCK_REMOTE_LIST" | tr -d ' ')"
  echo "   Total Size: 35"
elif [[ "$1 $2" == "s3 ls" && "$args" == *"--recursive"* ]]; then
  cat "$MOCK_REMOTE_LIST"
elif [[ "$1 $2" == "s3 ls" ]]; then
  echo "                           PRE video/gopro/"
elif [[ "$1 $2" == "s3 sync" ]]; then
  printf '%s' "${MOCK_DRYRUN_OUTPUT:-}"
elif [[ "$1" == "s3api" ]]; then
  echo "${MOCK_SAMPLE_KEY:?}"
elif [[ "$1 $2" == "s3 cp" ]]; then
  cp "${MOCK_RESTORE_SOURCE:?}" "$4"
else
  echo "Unexpected mock AWS call: $*" >&2
  exit 1
fi
EOF
chmod +x "$MOCK_BIN/aws"

run_verify() {
  local remote_list="$1"
  local dryrun_output="$2"
  local log_file="$3"
  shift 3

  PATH="$MOCK_BIN:$PATH" \
    BUCKET="test-bucket" \
    SOURCE_DIR="$SOURCE_DIR" \
    DEST_PREFIX="video/gopro" \
    EXPECTED_FILES="2" \
    RESTORE_DIR="$RESTORE_DIR" \
    MOCK_REMOTE_LIST="$remote_list" \
    MOCK_DRYRUN_OUTPUT="$dryrun_output" \
    MOCK_SAMPLE_KEY="video/gopro/clip_a.mp4" \
    "$SCRIPT" "$@" > "$log_file"
}

# Happy path: counts agree, dry run is clean, restore sample is skipped.
run_verify "$REMOTE_LIST_MATCHED" "" "$TMP_ROOT/pass.log"
grep -q 'PASS: Local and remote file counts match.' "$TMP_ROOT/pass.log"
grep -q 'PASS: Remote file count matches expected count.' "$TMP_ROOT/pass.log"
grep -q 'PASS: Dry run shows no remaining uploads.' "$TMP_ROOT/pass.log"
grep -q 'PASS: GoPro local source and S3 archive are synchronized.' "$TMP_ROOT/pass.log"
grep -q 'NOTICE: Restore integrity was not tested.' "$TMP_ROOT/pass.log"

# Count mismatch: an extra remote object must fail verification.
set +e
run_verify "$REMOTE_LIST_EXTRA" "" "$TMP_ROOT/mismatch.log"
mismatch_status="$?"
set -e
[[ "$mismatch_status" -eq 1 ]]
grep -q 'FAIL: Local and remote file counts do not match.' "$TMP_ROOT/mismatch.log"

# Unreconciled dry run: pending uploads must fail verification.
set +e
run_verify "$REMOTE_LIST_MATCHED" '(dryrun) upload: clip_b.mp4' "$TMP_ROOT/dryrun.log"
dryrun_status="$?"
set -e
[[ "$dryrun_status" -eq 1 ]]
grep -q 'FAIL: Dry run found remaining upload actions:' "$TMP_ROOT/dryrun.log"

# Restore sample, intact: the restored copy hashes identically.
MOCK_RESTORE_SOURCE="$SOURCE_DIR/clip_a.mp4" \
  run_verify "$REMOTE_LIST_MATCHED" "" "$TMP_ROOT/restore.log" --restore-sample
grep -q 'PASS: Restored sample matches the local SHA-256.' "$TMP_ROOT/restore.log"
grep -q 'PASS: Restored sample passed S3 and local SHA-256 validation.' "$TMP_ROOT/restore.log"
[[ -f "$RESTORE_DIR/clip_a.mp4" ]]

# Restore sample, corrupted: a hash mismatch must fail verification.
rm -rf "$RESTORE_DIR"
set +e
MOCK_RESTORE_SOURCE="$CORRUPT_SAMPLE" \
  run_verify "$REMOTE_LIST_MATCHED" "" "$TMP_ROOT/corrupt.log" --restore-sample
corrupt_status="$?"
set -e
[[ "$corrupt_status" -eq 1 ]]
grep -q 'FAIL: Restored sample does not match the local SHA-256.' "$TMP_ROOT/corrupt.log"

echo "PASS: GoPro sync verification passes intact archives and fails count, dry-run, and checksum drift."
