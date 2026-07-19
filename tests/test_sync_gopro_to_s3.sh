#!/usr/bin/env bash
set -euo pipefail

# Verifies the guard logic of scripts/sync_gopro_to_s3.sh: the default mode
# must never upload, the atomic lock must reject a concurrent run, a real
# upload must reconcile in the final dry run, and an unreconciled remote must
# fail loudly instead of reporting success.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$REPO_ROOT/scripts/sync_gopro_to_s3.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# The script hard-codes its lock path; a live lock means a real sync may be
# running, so the test must not proceed (or clean it up) in that case.
LOCK_DIR="/tmp/lifeos_gopro_s3_sync.lock"
if [[ -e "$LOCK_DIR" ]]; then
  echo "SKIP-FAIL: $LOCK_DIR already exists; not testing while a sync may be active." >&2
  exit 1
fi

SOURCE_DIR="$TMP_ROOT/gopro"
MOCK_BIN="$TMP_ROOT/bin"
LOG_DIR="$TMP_ROOT/logs"
REMOTE_LIST="$TMP_ROOT/remote_list.txt"
CALL_LOG="$TMP_ROOT/calls.log"

mkdir -p "$SOURCE_DIR" "$MOCK_BIN"
printf 'first clip bytes\n' > "$SOURCE_DIR/clip_a.mp4"
printf 'second clip bytes\n' > "$SOURCE_DIR/clip_b.mp4"

cat > "$REMOTE_LIST" <<'EOF'
2026-07-19 10:00:00         17 video/gopro/clip_a.mp4
2026-07-19 10:00:01         18 video/gopro/clip_b.mp4
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
elif [[ "$1 $2" == "s3 sync" && "$args" == *"--dryrun"* ]]; then
  printf 'dryrun-sync %s\n' "$args" >> "$MOCK_CALL_LOG"
  printf '%s' "${MOCK_DRYRUN_OUTPUT:-}"
elif [[ "$1 $2" == "s3 sync" ]]; then
  printf 'execute-sync %s\n' "$args" >> "$MOCK_CALL_LOG"
else
  echo "Unexpected mock AWS call: $*" >&2
  exit 1
fi
EOF
chmod +x "$MOCK_BIN/aws"

run_sync() {
  local log_file="$1"
  shift

  PATH="$MOCK_BIN:$PATH" \
    BUCKET="test-bucket" \
    SOURCE_DIR="$SOURCE_DIR" \
    DEST_PREFIX="video/gopro" \
    EXPECTED_FILES="2" \
    LOG_DIR="$LOG_DIR" \
    MOCK_REMOTE_LIST="$REMOTE_LIST" \
    MOCK_CALL_LOG="$CALL_LOG" \
    "$SCRIPT" "$@" > "$log_file"
}

# Default mode: a dry run that reports pending uploads must not upload.
MOCK_DRYRUN_OUTPUT='(dryrun) upload: clip_a.mp4' run_sync "$TMP_ROOT/dryrun.log"
grep -q 'Mode:           DRY RUN' "$TMP_ROOT/dryrun.log"
grep -q 'No files were uploaded.' "$TMP_ROOT/dryrun.log"
grep -q 'dryrun-sync' "$CALL_LOG"
if grep -q 'execute-sync' "$CALL_LOG"; then
  echo "FAIL: the default dry-run mode performed a real upload." >&2
  exit 1
fi

# Unknown arguments are rejected before any preflight action.
set +e
run_sync "$TMP_ROOT/badarg.log" --bogus
badarg_status="$?"
set -e
[[ "$badarg_status" -eq 1 ]]
grep -q 'ERROR: Unknown argument: --bogus' "$TMP_ROOT/badarg.log"

# A held lock must reject a second run.
mkdir "$LOCK_DIR"
set +e
run_sync "$TMP_ROOT/locked.log"
locked_status="$?"
set -e
rmdir "$LOCK_DIR"
[[ "$locked_status" -eq 1 ]]
grep -q "ERROR: Lock exists: $LOCK_DIR" "$TMP_ROOT/locked.log"

# Execute mode: upload runs with SHA-256 checksums and reconciles cleanly.
: > "$CALL_LOG"
run_sync "$TMP_ROOT/execute.log" --execute --no-progress
grep -q 'execute-sync .*--checksum-algorithm SHA256' "$CALL_LOG"
grep -q 'PASS: Final dry run shows no remaining uploads.' "$TMP_ROOT/execute.log"
grep -q 'PASS: Local and remote file counts match.' "$TMP_ROOT/execute.log"
grep -q 'PASS: Remote file count matches expected count.' "$TMP_ROOT/execute.log"
[[ -n "$(find "$LOG_DIR" -name 'gopro_sync_*.log' -type f)" ]]
[[ ! -e "$LOCK_DIR" ]]

# Execute mode with an unreconciled remote: the final dry run still shows
# pending uploads, so the script must fail instead of reporting success.
set +e
MOCK_DRYRUN_OUTPUT='(dryrun) upload: clip_b.mp4' \
  run_sync "$TMP_ROOT/unreconciled.log" --execute --no-progress
unreconciled_status="$?"
set -e
[[ "$unreconciled_status" -eq 1 ]]
grep -q 'FAIL: Final dry run found remaining upload actions:' "$TMP_ROOT/unreconciled.log"
grep -q 'Upload verification failed.' "$TMP_ROOT/unreconciled.log"
[[ ! -e "$LOCK_DIR" ]]

echo "PASS: GoPro sync stays dry by default, honors the lock, and fails unreconciled uploads."
