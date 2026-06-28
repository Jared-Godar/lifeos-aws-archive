#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper for the original resume command. S3 sync is already
# resumable, so delegate to the guarded upload workflow to share its atomic
# lock, checksum settings, logging, and strict verification behavior.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ -n "${TOTAL_EXPECTED_FILES:-}" && -z "${EXPECTED_FILES:-}" ]]; then
  export EXPECTED_FILES="$TOTAL_EXPECTED_FILES"
fi

echo "Resuming through sync_gopro_to_s3.sh with the shared upload lock."
exec "$SCRIPT_DIR/sync_gopro_to_s3.sh" --execute --no-progress "$@"
