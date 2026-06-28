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

SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd -P)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
FILE_LIST="$OUTPUT_DIR/${LABEL}_file_list_${TIMESTAMP}.txt"
SHA256_MANIFEST="$OUTPUT_DIR/${LABEL}_sha256_${TIMESTAMP}.txt"

echo "Source: $SOURCE_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "File list: $FILE_LIST"
echo "SHA256 manifest: $SHA256_MANIFEST"
echo

sorted_files() {
  (
    cd "$SOURCE_DIR"
    find . -type f -print0 | LC_ALL=C sort -z
  )
}

echo "Generating file list..."
TOTAL_FILES=0
while IFS= read -r -d '' FILE; do
  TOTAL_FILES=$((TOTAL_FILES + 1))
done < <(sorted_files)

echo "Files found: $TOTAL_FILES"
echo

echo "Generating SHA256 manifest..."
COUNT=0
: > "$FILE_LIST"
: > "$SHA256_MANIFEST"

while IFS= read -r -d '' FILE; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL_FILES] $FILE"
  printf '%q\n' "$FILE" >> "$FILE_LIST"
  (
    cd "$SOURCE_DIR"
    shasum -a 256 -- "$FILE"
  ) >> "$SHA256_MANIFEST"
done < <(sorted_files)

echo
echo "Manifest generation complete."
echo "File list: $FILE_LIST"
echo "SHA256 manifest: $SHA256_MANIFEST"
echo "Verify a restored collection from its root with:"
echo "  shasum -a 256 -c \"$SHA256_MANIFEST\""
