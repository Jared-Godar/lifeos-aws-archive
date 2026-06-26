#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-}"
OUTPUT_DIR="${2:-manifests}"
LABEL="${3:-archive}"

if [[ -z "$SOURCE_DIR" ]]; then
  echo "Usage: scripts/generate_manifest.sh SOURCE_DIR [OUTPUT_DIR] [LABEL]"
  echo
  echo "Example:"
  echo "  scripts/generate_manifest.sh ~/Movies/GoPro manifests gopro"
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Source directory does not exist: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
FILE_LIST="$OUTPUT_DIR/${LABEL}_file_list_${TIMESTAMP}.txt"
SHA256_MANIFEST="$OUTPUT_DIR/${LABEL}_sha256_${TIMESTAMP}.txt"

echo "Source: $SOURCE_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "File list: $FILE_LIST"
echo "SHA256 manifest: $SHA256_MANIFEST"
echo

echo "Generating file list..."
find "$SOURCE_DIR" -type f | sort > "$FILE_LIST"

TOTAL_FILES="$(wc -l < "$FILE_LIST" | tr -d ' ')"
echo "Files found: $TOTAL_FILES"
echo

echo "Generating SHA256 manifest..."
COUNT=0

while IFS= read -r FILE; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL_FILES] $FILE"
  shasum -a 256 "$FILE" >> "$SHA256_MANIFEST"
done < "$FILE_LIST"

echo
echo "Manifest generation complete."
echo "File list: $FILE_LIST"
echo "SHA256 manifest: $SHA256_MANIFEST"