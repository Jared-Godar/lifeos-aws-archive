# Change Log

| Date       | Notes                                                                 |
| ---------- | --------------------------------------------------------------------- |
| 2026-06-28 | Added repository linting and completed two project hardening reviews. |

---

## 2026-06-28

- [x] Added Markdown linting and formatting configuration for the CLI and VS Code.
- [x] Added npm scripts and locked development dependencies.
- [x] Integrated CloudFormation and shell validation with repository tooling.
- [x] Added a guarded, collection-aware manifest uploader with dry-run and checksum verification.

## Project Review I — Completed

1. [x] Aligned lifecycle rules with the documented S3 taxonomy.
2. [x] Added checksum-backed upload and restored-sample integrity verification.
3. [x] Added the required bucket parameter to deployment commands.
4. [x] Made post-upload verification failures return a nonzero status.
5. [x] Replaced the racy sync lock with an atomic lock directory.
6. [x] Made generated manifests portable by recording relative paths.
7. [x] Made restore sampling safe for object keys containing spaces.

## Project Review II — Completed

1. [x] Updated the runbook to use the guarded upload workflow.
2. [x] Consolidated resume uploads behind the primary sync script and shared lock.
3. [x] Retained the TLS-enforcement bucket policy with the retained archive bucket.
4. [x] Replaced stale TODOs and workstation-local links in this change log.
5. [x] Expanded CI to validate CloudFormation, shell scripts, and Markdown.
6. [x] Updated project documentation to distinguish implemented and planned features.
7. [x] Made manifest generation safe for filenames containing newline characters.

---

## Feature: # Collection-Aware Manifest Uploader

### Summary

Add `scripts/upload_manifests_to_s3.sh` as the guarded, reusable upload path for generated manifests. It will default to GoPro, read the bucket from `.env.private`, perform a dry run unless explicitly executed, and never upload `.gitkeep`.

### Implementation

- Configuration precedence:
  - `BUCKET` environment override.
  - Otherwise load `BUCKET_NAME` from repository-root `.env.private`.
  - Fail clearly if neither exists.
- Default `COLLECTION=gopro`; allow safe collection labels such as `photos` or `obsidian`.
- Upload only `manifests/${COLLECTION}_*.txt` to `s3://$BUCKET/manifests/$COLLECTION/`.
- Exclude all unrelated files and `*.gitkeep`; never use `--delete`.
- Support `--execute` and `--help`; default to a visible `aws s3 sync --dryrun`.
- On execution, use `--checksum-algorithm SHA256`, an atomic per-collection lock, and a final dry-run verification that exits nonzero if uploads remain.
- Update the runbook, README repository tree, change log, and CloudFormation example output to use the new script.

### Interface

```bash
scripts/upload_manifests_to_s3.sh
scripts/upload_manifests_to_s3.sh --execute
COLLECTION=photos scripts/upload_manifests_to_s3.sh --execute
BUCKET=alternate-bucket COLLECTION=gopro scripts/upload_manifests_to_s3.sh
```

Optional overrides: `BUCKET`, `COLLECTION`, `MANIFEST_DIR`, `DEST_PREFIX`, and `ENV_FILE`.

### Test Plan

- Run ShellCheck, Bash syntax validation, Markdown lint, `cfn-lint`, and the full pre-commit suite.
- Use a temporary mocked `aws` command to confirm:
  - Dry-run is the default.
  - `--execute` adds SHA-256 checksums.
  - Only collection-matching `.txt` files are selected.
  - `.gitkeep` and other collections are excluded.
  - Missing bucket configuration, invalid collection names, no matching manifests, AWS failures, and incomplete final verification return nonzero.
- Do not perform a live S3 upload during implementation.

### Assumptions

- `.env.private` defines `BUCKET_NAME`.
- Manifests remain flat in the local `manifests/` directory and follow `${COLLECTION}_*.txt`.
- Historical manifests are retained locally and remotely; the script uploads missing or changed files without deleting older remote manifests.

---

## OPERATIONAL: BACKUP

The next phase should be collection-by-collection archival, not whole-Mac backup. Your framework is excellent for finalized files, but it is not yet a Time Machine replacement: S3 does not preserve every macOS filesystem attribute, and versioning stores complete copies of changed objects, which can increase cost for frequently edited files. [AWS versioning behavior](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)

## Recommended order

| Location  |   Size | Treatment                                                         |
| --------- | -----: | ----------------------------------------------------------------- |
| Movies    | 179 GB | Finish GoPro retention, then inspect remaining completed media    |
| Pictures  |  88 GB | Next archive target, but use normal folders or exported originals |
| Documents |  46 GB | Triage carefully; do not bulk-upload                              |
| Downloads |  18 GB | Clean first; archive only irreplaceable items                     |
| Music     | 2.7 GB | Later                                                             |
| Desktop   | 1.8 GB | Organize into appropriate collections first                       |

Important: inspect document inventories for credential exports and exclude them from every archive workflow.

## Best next pilot

Choose one self-contained 1–5 GB event folder containing ordinary image/video files outside the Photos library package.

Use this process:

1. Confirm it contains no symlinks:

```bash
find "$HOME/Pictures/SELECTED_FOLDER" -type l -print
```

1. Count files:

```bash
find "$HOME/Pictures/SELECTED_FOLDER" -type f | wc -l
```

1. Dry-run through the existing framework:

```bash
BUCKET="lifeos-archive-example" \
SOURCE_DIR="$HOME/Pictures/SELECTED_FOLDER" \
DEST_PREFIX="photos/events/YYYY/SELECTED_FOLDER" \
EXPECTED_FILES="FILE_COUNT" \
scripts/sync_gopro_to_s3.sh
```

1. Execute only after reviewing the destination:

```bash
BUCKET="lifeos-archive-example" \
SOURCE_DIR="$HOME/Pictures/SELECTED_FOLDER" \
DEST_PREFIX="photos/events/YYYY/SELECTED_FOLDER" \
EXPECTED_FILES="FILE_COUNT" \
scripts/sync_gopro_to_s3.sh --execute
```

1. Generate, upload, and verify its manifest; restore a sample before cleanup.

## Special cases

- Do not directly sync `Photos Library.photoslibrary`. Export **Unmodified Originals**, optionally with XMP metadata, into ordinary folders first. [Apple export guidance](https://support.apple.com/en-ie/guide/photos/pht6e157c5f/mac)
- Do not directly sync live iMovie, Lightroom, or similar library packages.
- Do not upload `.ssh`, `.aws`, password exports, `.env` files, browser profiles, or cloud-provider placeholders.
- AWS CLI follows symlinks by default, so use staged folders without symlinks until the framework explicitly adds `--no-follow-symlinks`. [AWS CLI sync behavior](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html)

Your immediate operational goal should be: complete one photo-event pilot, document what felt awkward, then scale the proven workflow across remaining event folders.

---

- [x] `open -R "$HOME/Pictures/Photos Library.photoslibrary"`
- [x] `mkdir -p "$HOME/Pictures/Photo Exports/$(date +%Y)"`
- [x] `open "$HOME/Pictures/Photo Exports/$(date +%Y)"`
- [x] `defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
killall Finder`
- [x] Half GB, 319 image test folder
  - `/Users/example/Pictures/Photo Exports`
  - `'/Users/example/Pictures/Photo Exports/testUpload'`
  - 318 files
  - 509 MB
  - 0 symlinks
  - 159 media files
  - 159 matching XMP sidecars
  - The pairing is perfect:
    - 155 JPG
    - 1 JPEG
    - 1 PNG
    - 2 MOV
    - 159 XMP
- [x] Run the dry run:

```bash
BUCKET="lifeos-archive-example" \
SOURCE_DIR="$HOME/Pictures/Photo Exports/testUpload" \
DEST_PREFIX="photos/ingest/test-upload-2026-06-28" \
EXPECTED_FILES="318" \
scripts/sync_gopro_to_s3.sh
```

- [x] Execute

```bash
BUCKET="lifeos-archive-example" \
SOURCE_DIR="$HOME/Pictures/Photo Exports/testUpload" \
DEST_PREFIX="photos/ingest/test-upload-2026-06-28" \
EXPECTED_FILES="318" \
scripts/sync_gopro_to_s3.sh --execute
```

- [x] Next, perform restore-and-checksum validation:

```bash
BUCKET="lifeos-archive-example" \
SOURCE_DIR="$HOME/Pictures/Photo Exports/testUpload" \
DEST_PREFIX="photos/ingest/test-upload-2026-06-28" \
EXPECTED_FILES="318" \
scripts/verify_gopro_sync.sh --restore-sample
```

- [x]The automated verification passed completely, including XMP checksum integrity. Now validate an actual photo:

```bash
mkdir -p restore-tests/photos

aws s3 cp \
  "s3://lifeos-archive-example/photos/ingest/test-upload-2026-06-28/example-photo.jpg" \
  "restore-tests/photos/example-photo.jpg" \
  --checksum-mode ENABLED

shasum -a 256 \
  "$HOME/Pictures/Photo Exports/testUpload/example-photo.jpg" \
  "restore-tests/photos/example-photo.jpg"

open -a Preview "restore-tests/photos/example-photo.jpg"
```

- [x] the SHA-256 hashes match exactly. The restored photo is byte-for-byte identical to the original.
  - [x] The photo pilot has passed:
    - [x] Complete upload: 318/318 files
    - [x] Final sync: clean
    - [x] XMP restore: verified
    - [x] JPEG restore: verified
    - [x] After visually checking the JPEG, you can mark this pilot successful. Keep the local files until manifests are generated and uploaded.

- [x] CLose pilot with manifests

```bash
scripts/generate_manifest.sh \
  "$HOME/Pictures/Photo Exports/testUpload" \
  manifests \
  photos
```

- [x] Preview and upload

```bash
COLLECTION=photos scripts/upload_manifests_to_s3.sh
COLLECTION=photos scripts/upload_manifests_to_s3.sh --execute
```

---
