# Change Log

| Date       | Notes                                                                                    |
| ---------- | ---------------------------------------------------------------------------------------- |
| 2026-06-29 | Recovered an unmerged cloud PR and corrected repository validation and restore tooling.  |
| 2026-06-28 | Added validation, hardening reviews, portfolio documentation, and an AWS budget runbook. |

---

## 2026-06-29 — Repository Validation and PR Recovery

### Incident and recovery

GitHub Actions failed because its wildcard CloudFormation command treated
`cloudformation/tags.yaml`, a reusable tag document, as a complete deployable
template. Local pre-commit configuration already excluded that file, but the CI
workflow and proposed repository-validation script did not use the same scope.

Codex cloud PR #1 proposed several useful validation and restore improvements,
but follow-up repair commits remained inside isolated cloud task environments
and could not be pushed to the PR branch. The PR was closed without merging.
The useful changes were reviewed, corrected, and recreated locally from the
current `origin/main` instead of merging the stale branch.

### Completed changes

- [x] Added `scripts/validate_repo.sh` as the local entrypoint for CloudFormation, ShellCheck, and Markdown validation.
- [x] Limited CloudFormation linting to `cloudformation/lifeos-s3-archive.yaml` in CI and local validation.
- [x] Kept `cloudformation/tags.yaml` available as a tag document without treating it as a deployable template.
- [x] Extended ShellCheck coverage to production scripts and test scripts.
- [x] Added an `npm ci` bootstrap when Markdown tooling is missing from a fresh checkout.
- [x] Added the pinned ShellCheck development dependency and regenerated `uv.lock` without downgrading its lock format.
- [x] Replaced raw CloudFormation example uploads with the guarded sync and manifest uploader workflows.
- [x] Replaced the verifier's shared temporary filename with a unique `mktemp` file and automatic cleanup.
- [x] Preserved nested S3 object paths when restoring verification samples.
- [x] Added checksum-backed test upload and restore examples to the runbook.
- [x] Replaced manual interrupted-upload and verification examples with guarded repository scripts.
- [x] Documented the unified validator in the README and repository tree.
- [x] Completed a production-photo smoke test with 56 files and 45,058,125 bytes reconciled in S3.
- [x] Verified restored XMP and JPEG samples by SHA-256 and visual comparison.
- [x] Added explicit confirmation handling and a safe, idempotent `--resume` path for interrupted photo batches.

### Validation evidence

The recovered local change set passed:

- `uv run scripts/validate_repo.sh`
- CloudFormation validation
- ShellCheck for `scripts/*.sh` and `tests/*.sh`
- Markdown linting
- The complete pre-commit suite
- `git diff --check`

No live CloudFormation deployment or S3 mutation was performed during this
recovery.

### Production photo smoke test and resume handling

The production helper uploaded and reconciled a 56-file photo batch totaling
45,058,125 bytes. Restored XMP and JPEG samples matched their local SHA-256
values, and the original and restored JPEG matched visually. Terminal input
closed at the visual-confirmation prompt, so the workflow correctly stopped
before manifest generation, manifest upload, and reminder creation.

The helper now distinguishes blank input, an explicit `n`, and closed terminal
input. It prints a fish-compatible resume command, exits with status 3 for an
incomplete but safely resumable workflow, and supports `--resume`. Resume mode
repeats checksum-backed synchronization and verification without deleting S3
objects or re-uploading unchanged files.

---

## 2026-06-28

- [x] Added Markdown linting and formatting configuration for the CLI and VS Code.
- [x] Added npm scripts and locked development dependencies.
- [x] Integrated CloudFormation and shell validation with repository tooling.
- [x] Added a guarded, collection-aware manifest uploader with dry-run and checksum verification.
- [x] Documented a `$10` monthly AWS cost budget with actual and forecasted alerts.
- [x] Added budget validation, alert-response, monthly review, and troubleshooting procedures.

## Cost Management Documentation

The new [AWS budget runbook](AWSbudget.md) documents the planned account-wide
cost guardrail without representing the budget as already configured. It
includes four email thresholds, recommends avoiding automated budget actions
during initial adoption, and connects alerts to the recurring monthly archive
and cost review.

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

## Next Steps

> 20260929

### Before scaling

- [ ] Create the AWS budget.
- [ ] Verify it appears correctly the following day.
- [ ] Deploy the pending CloudFormation updates.
- [ ] Validate encryption, versioning, public-access blocking, TLS enforcement, logging, and lifecycle rules.

### First production batch

- [ ] Choose one coherent album or year totaling 5–20 GiB.
- [ ] Export unmodified originals
- [ ] Include XMP sidecars
- [ ] Use a unique folder, such as:

```bash
`~/Pictures/Photo Exports/2025-family`
```

- [ ] Use a matching S3 prefix:

```bash
photos/ingest/2025-family/
```

> Do not upload the Photos Library.photoslibrary package directly.

### Execute the proven workflow

- [ ] Count and inspect local files.
- [ ] Run the upload dry run.
- [ ] Execute the upload.
- [ ] Compare local and remote counts.
- [ ] Confirm the final dry run is empty.
- [ ] Restore an XMP file.
- [ ] Restore and visually inspect a JPEG or video.
- [ ] Confirm SHA-256 hashes match.
- [ ] Generate batch-specific manifests.
- [ ] Upload the manifests.
- [ ] Record the result in Trello.
- [ ] Use a distinct manifest label such as:

```bash
scripts/generate_manifest.sh \
  "$HOME/Pictures/Photo Exports/2025-family" \
  manifests \
  photos_2025_family
```

```bash
COLLECTION=photos_2025_family scripts/upload_manifests_to_s3.sh
COLLECTION=photos_2025_family scripts/upload_manifests_to_s3.sh --execute
```

### After validation

- [ ] Keep the local batch for 3–7 days.
- [ ] Before deleting anything from Apple Photos, confirm you understand the iCloud deletion behavior and preferably retain another independent copy.
- [ ] Deleting only the exported folder does not reduce the Photos library.
- [ ] Repeat this process batch-by-batch, reviewing AWS costs after the first two production uploads.

---

## Execution Order

> Budget → CloudFormation Deployment → Security Validation → First Production Batch

---

## New Feature: `$[archive_photo_batch.sh`

- Interactive Run

```bash
scripts/archive_photo_batch.sh
```

- Explicit Run

```bash
scripts/archive_photo_batch.sh \
  --source "$HOME/Pictures/Photo Exports/2025 Family" \
  --label 2025-family \
  --cooloff-days 7
```

- It handles:
  - macOS folder selection
  - Confirmed standardized folder rename
  - Standard S3 and manifest prefixes
  - Dry run and explicit upload checkpoint
  - Count, byte, and final dry-run reconciliation
  - XMP and media restore/checksum validation
  - Original/restored media opening and visual confirmation
  - Manifest generation and upload
  - Private verification record
  - ICS cooling-off reminder
  - No automatic deletion

Added a mocked end-to-end test and updated all relevant documentation. No live upload was performed. All validation checks pass.

### AUTOMATED TEST

- The automated test creates a disposable two-file photo batch containing:
  - `photo.jpg`
  - `photo.xmp`
- It mocks AWS, upload scripts, and file opening, then cleans everything afterward. Run:

```bash
tests/test_archive_photo_batch.sh
```

- Expected Result:

```bash

```

---

## AWS IAM access-key profile

> 20260629

```bash
aws configure --profile lifeos
```

Create an IAMuser for the key.

### Policy (least access principal)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ArchiveBucketList",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": "arn:aws:s3:::<ARCHIVE_BUCKET_PREFIX>*"
    },
    {
      "Sid": "ArchiveObjectReadWriteNoDelete",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectAttributes",
        "s3:GetObjectTagging",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAttributes",
        "s3:GetObjectVersionTagging",
        "s3:PutObject",
        "s3:PutObjectTagging"
      ],
      "Resource": "arn:aws:s3:::<ARCHIVE_BUCKET_PREFIX>*/*"
    },
    {
      "Sid": "ArchiveBucketConfigReadWrite",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetLifecycleConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:GetBucketLogging",
        "s3:PutBucketLogging",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging"
      ],
      "Resource": "arn:aws:s3:::<ARCHIVE_BUCKET_PREFIX>*"
    },
    {
      "Sid": "CloudFormationArchiveDeploy",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:CreateChangeSet",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:DeleteChangeSet",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:DescribeStackResources",
        "cloudformation:GetTemplate",
        "cloudformation:GetTemplateSummary",
        "cloudformation:ListStackResources",
        "cloudformation:ValidateTemplate"
      ],
      "Resource": "*"
    },
    {
      "Sid": "BudgetManagement",
      "Effect": "Allow",
      "Action": [
        "budgets:ModifyBudget",
        "budgets:ViewBudget",
        "budgets:TagResource",
        "budgets:UntagResource",
        "budgets:ListTagsForResource"
      ],
      "Resource": "arn:aws:budgets::<ACCOUNT_ID>:budget/*"
    },
    {
      "Sid": "BudgetInitialServiceLinkedRole",
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": "budgets.amazonaws.com"
        }
      }
    },
    {
      "Sid": "BudgetConsoleBillingView",
      "Effect": "Allow",
      "Action": "billing:GetBillingViewData",
      "Resource": "*"
    },
    {
      "Sid": "IamReadOnlyDiagnostics",
      "Effect": "Allow",
      "Action": [
        "iam:GetUser",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:GetUserPolicy",
        "iam:ListAccessKeys",
        "iam:ListAttachedRolePolicies",
        "iam:ListAttachedUserPolicies",
        "iam:ListEntitiesForPolicy",
        "iam:ListPolicies",
        "iam:ListPolicyVersions",
        "iam:ListRolePolicies",
        "iam:ListRoles",
        "iam:ListUserPolicies",
        "iam:ListUsers"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IdentityChecks",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    }
  ]
}
```

#### Shared tags (user, policy, and access key)

| Key             | Example Value      | Notes                                   |
| --------------- | ------------------ | --------------------------------------- |
| Project         | lifeos-aws-archive | Owning project                          |
| Environment     | personal-prod      | Environment classification              |
| Owner           | jared-godar        | Responsible owner                       |
| Purpose         | archive-automation | Primary use case                        |
| ManagedBy       | manual             | manual, cloudformation, terraform, etc. |
| CreatedDate     | 2026-06-29         | ISO-8601 creation date                  |
| ReviewDate      | 2026-09-29         | Next access review date                 |
| RotationDate    | 2026-09-29         | Planned access-key rotation date        |
| DataClass       | personal-archive   | Data sensitivity classification         |
| PrivilegeLevel  | least-access       | Permission model                        |
| CostCenter      | personal           | Billing grouping                        |
| Repository      | lifeos-aws-archive | Source repository                       |
| AutomationScope | single-bucket      | Intended scope                          |
| IncidentContact | jared-godar        | Responsible contact                     |
| ComplianceScope | none               | Optional compliance boundary            |
| BackupTier      | archive            | Archive, backup, hot, etc.              |
| Lifecycle       | active             | active, deprecated, retired             |

#### IAM user specific tags

| Key                | Example Value  |
| ------------------ | -------------- |
| UserType           | service-user   |
| AuthenticationType | access-key     |
| AccessType         | cli-and-vscode |

#### IAM policy specific tags

| Key           | Example Value |
| ------------- | ------------- |
| PolicyScope   | bucket-only   |
| PolicyVersion | v1            |
| ReviewCadence | quarterly     |

#### TAGS JSON

```json
[
  {
    "Key": "Project",
    "Value": "lifeos-aws-archive"
  },
  {
    "Key": "Environment",
    "Value": "personal-prod"
  },
  {
    "Key": "Owner",
    "Value": "jared-godar"
  },
  {
    "Key": "Purpose",
    "Value": "archive-automation"
  },
  {
    "Key": "ManagedBy",
    "Value": "manual"
  },
  {
    "Key": "CreatedDate",
    "Value": "2026-06-29"
  },
  {
    "Key": "ReviewDate",
    "Value": "2026-09-29"
  },
  {
    "Key": "RotationDate",
    "Value": "2026-09-29"
  },
  {
    "Key": "Lifecycle",
    "Value": "active"
  },
  {
    "Key": "PrivilegeLevel",
    "Value": "least-access"
  },
  {
    "Key": "Repository",
    "Value": "lifeos-aws-archive"
  }
]
```

#### TAGS YAML

```yaml
Tags:
  - Key: Project
    Value: lifeos-aws-archive
  - Key: Environment
    Value: personal-prod
  - Key: Owner
    Value: jared-godar
  - Key: Purpose
    Value: archive-automation
  - Key: ManagedBy
    Value: manual
  - Key: CreatedDate
    Value: "2026-06-29"
  - Key: ReviewDate
    Value: "2026-09-29"
  - Key: RotationDate
    Value: "2026-09-29"
  - Key: Lifecycle
    Value: active
  - Key: PrivilegeLevel
    Value: least-access
  - Key: Repository
    Value: lifeos-aws-archive
```

### Configure Access Key

```bash
aws configure --profile lifeos
```

```bash
AWS Access Key ID: <new access key id>
AWS Secret Access Key: <new secret access key>
Default region name: us-east-1
Default output format: json
```

#### TEST

```bash
aws sts get-caller-identity --profile lifeos
```

_Expected Output:_

```bash
arn:aws:iam::<ACCOUNT_ID>:user/lifeos-archive-user
```

Make this profile default for your current terminal session:

```bash
set -gx AWS_PROFILE lifeos
```

Persist it:

```bash
echo 'set -gx AWS_PROFILE lifeos' >> ~/.config/fish/config.fish
```

---

## VALIDATE CODE CHANGES

> 20260629

- [ ] 1. **Confirm prerequisites** Before bulk uploads, ensure:
  - [ ] AWS budget alerts are active
  - [ ] Current CloudFormation changes are deployed
  - [ ] Encryption, versioning, public-access blocking, logging, and lifecycle rules are verified

- [ ] Validate the repository

```bash
cd "/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive"

git pull --ff-only origin main
uv sync --group dev
uv run scripts/validate_repo.sh
```

- [x] 2. Run a live smoke test
  - [x] Export a noncritical Photos batch containing JPEG or HEIC media and XMP sidecars. Keep it below approximately 500 MB. Export into:

```txt
~/Pictures/Photo Exports/live-smoke-test
```

- [x] Run:

```bash
scripts/archive_photo_batch.sh \
  --source "$HOME/Pictures/Photo Exports/live-smoke-test" \
  --label live-smoke-test \
  --cooloff-days 3
```

The destination will be:

```txt
s3://YOUR_BUCKET/photos/ingest/live-smoke-test/
```
