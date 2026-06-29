#!/usr/bin/env bash
set -euo pipefail

# Run the local equivalent of the repository validation workflow.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

SHELL_FILES=()
while IFS= read -r -d '' file; do
  SHELL_FILES+=("$file")
done < <(find scripts tests -type f -name '*.sh' -print0 | LC_ALL=C sort -z)

cfn-lint cloudformation/lifeos-s3-archive.yaml
shellcheck "${SHELL_FILES[@]}"

if [[ ! -x node_modules/.bin/remark ]]; then
  npm ci
fi

npm run lint:md
