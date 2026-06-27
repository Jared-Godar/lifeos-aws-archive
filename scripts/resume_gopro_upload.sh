#!/usr/bin/env bash
set -euo pipefail

BUCKET="${BUCKET:-lifeos-archive-example}"
SOURCE_DIR="${SOURCE_DIR:-$HOME/Movies/GoPro}"
DEST="s3://${BUCKET}/video/gopro/"
LOG_DIR="logs"

mkdir -p "$LOG_DIR"

echo "LifeOS GoPro Upload Resume"
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST"
echo

echo "Current remote status:"
aws s3 ls "$DEST" --recursive --summarize | tail -2 || true
echo

echo "Dry-run check for remaining uploads:"
aws s3 sync "$SOURCE_DIR" "$DEST" --dryrun
echo

echo "Starting/resuming upload..."
aws s3 sync "$SOURCE_DIR" "$DEST" --no-progress 2>&1 | tee "$LOG_DIR/gopro_sync_$(date +%Y%m%d_%H%M%S).log"

echo
echo "Post-upload remote status:"
aws s3 ls "$DEST" --recursive --summarize | tail -2

echo
echo "Resume script complete."