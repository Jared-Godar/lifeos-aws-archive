#!/usr/bin/env bash
set -euo pipefail

# LifeOS Archive - Public Sanitization Helper
#
# Purpose:
#   Replace private/local identifiers in the current working tree with
#   public-safe placeholder values before publishing or portfolio review.
#
# Private values are loaded from:
#   .env.private
#
# This script is safe to commit because it contains no private identifiers.
#
# Usage:
#   scripts/sanitize_private_values.sh
#
# Required .env.private variables:
#   ACCOUNT_ID
#   IAM_USERNAME
#   BUCKET_NAME
#   LOCAL_USERNAME
#   HOME_DIRECTORY
#   GOPRO_SOURCE_DIR
#   PHOTOS_LIBRARY
#   PUBLIC_ACCOUNT_ID
#   PUBLIC_IAM_USERNAME
#   PUBLIC_BUCKET_NAME
#   PUBLIC_LOCAL_USERNAME
#   PUBLIC_OWNER_NAME

ENV_FILE=".env.private"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing $ENV_FILE"
  echo "Create $ENV_FILE in the repository root before running this script."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required_vars=(
  ACCOUNT_ID
  IAM_USERNAME
  BUCKET_NAME
  LOCAL_USERNAME
  HOME_DIRECTORY
  GOPRO_SOURCE_DIR
  PHOTOS_LIBRARY
  PUBLIC_ACCOUNT_ID
  PUBLIC_IAM_USERNAME
  PUBLIC_BUCKET_NAME
  PUBLIC_LOCAL_USERNAME
  PUBLIC_OWNER_NAME
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: Missing required variable in $ENV_FILE: $var"
    exit 1
  fi
done

replace_in_file() {
  local file="$1"
  local search="$2"
  local replacement="$3"

  if [[ -f "$file" ]]; then
    SEARCH="$search" REPLACEMENT="$replacement" perl -pi -e 's/\Q$ENV{SEARCH}\E/$ENV{REPLACEMENT}/g' "$file"
  fi
}

replace_in_files() {
  local search="$1"
  local replacement="$2"
  shift 2

  for file in "$@"; do
    replace_in_file "$file" "$search" "$replacement"
  done
}

echo "Sanitizing current working tree..."

docs_files=(
  README.md
  docs/archive-strategy.md
  docs/media-taxonomy.md
  docs/runbook.md
)

script_files=(
  scripts/resume_gopro_upload.sh
  scripts/sync_gopro_to_s3.sh
  scripts/verify_gopro_sync.sh
)

cloudformation_files=(
  cloudformation/lifeos-s3-archive.yaml
)

all_public_files=(
  "${docs_files[@]}"
  "${script_files[@]}"
  "${cloudformation_files[@]}"
)

replace_in_files "$ACCOUNT_ID" "$PUBLIC_ACCOUNT_ID" "${all_public_files[@]}"
replace_in_files "$IAM_USERNAME" "$PUBLIC_IAM_USERNAME" "${all_public_files[@]}"
replace_in_files "$BUCKET_NAME" "$PUBLIC_BUCKET_NAME" "${all_public_files[@]}"
replace_in_files "$LOCAL_USERNAME" "$PUBLIC_LOCAL_USERNAME" "${all_public_files[@]}"
replace_in_files "$HOME_DIRECTORY" "/Users/$PUBLIC_LOCAL_USERNAME" "${all_public_files[@]}"
replace_in_files "$GOPRO_SOURCE_DIR" "/Users/$PUBLIC_LOCAL_USERNAME/Movies/GoPro" "${all_public_files[@]}"
replace_in_files "$PHOTOS_LIBRARY" "/Users/$PUBLIC_LOCAL_USERNAME/Pictures/Photos Library.photoslibrary" "${all_public_files[@]}"

replace_in_files "arn:aws:iam::${PUBLIC_ACCOUNT_ID}:user/${IAM_USERNAME}" \
  "arn:aws:iam::${PUBLIC_ACCOUNT_ID}:user/${PUBLIC_IAM_USERNAME}" \
  "${all_public_files[@]}"

replace_in_files "arn:aws:iam::${ACCOUNT_ID}:user/${PUBLIC_IAM_USERNAME}" \
  "arn:aws:iam::${PUBLIC_ACCOUNT_ID}:user/${PUBLIC_IAM_USERNAME}" \
  "${all_public_files[@]}"

replace_in_files "arn:aws:iam::${ACCOUNT_ID}:user/${IAM_USERNAME}" \
  "arn:aws:iam::${PUBLIC_ACCOUNT_ID}:user/${PUBLIC_IAM_USERNAME}" \
  "${all_public_files[@]}"

replace_in_files "Jared-Godar" "$PUBLIC_OWNER_NAME" "${all_public_files[@]}"
replace_in_files "lifeos-archive-example" "$PUBLIC_BUCKET_NAME" "${all_public_files[@]}"

echo "Removing generated manifests from git tracking..."
git rm --cached -r manifests >/dev/null 2>&1 || true

mkdir -p manifests
touch manifests/.gitkeep

if ! grep -q "manifests/\*" .gitignore; then
  cat >> .gitignore <<'GITIGNORE'

# Generated manifests
manifests/*
!manifests/.gitkeep
GITIGNORE
fi

if ! grep -q ".env.private" .gitignore; then
  cat >> .gitignore <<'GITIGNORE'

# Local secrets and machine-specific configuration
.env.private
GITIGNORE
fi

if ! grep -q "scripts/logs/" .gitignore; then
  cat >> .gitignore <<'GITIGNORE'

# Script runtime logs
scripts/logs/
GITIGNORE
fi

echo
echo "Current working tree audit:"
grep -RInE "${ACCOUNT_ID}|${IAM_USERNAME}|${BUCKET_NAME}|${LOCAL_USERNAME}|Jared-Godar|arn:aws:iam::${ACCOUNT_ID}|${HOME_DIRECTORY}" . \
  --exclude-dir=.git \
  --exclude-dir=logs \
  --exclude-dir=scripts/logs \
  --exclude-dir=test-data \
  --exclude="$ENV_FILE" || true

echo
echo "Sanitization complete."
echo "Review any audit hits above before committing."
