# LifeOS Archive Runbook

## Purpose

This runbook documents the deployment, operation, validation, maintenance, and recovery procedures for the LifeOS Archive environment.

The objective is to ensure that future-you can deploy, operate, troubleshoot, and recover the archive without relying on memory or reconstructing prior decisions.

---

## Environment

### AWS Account

Current Account:

```bash
aws sts get-caller-identity
```

Expected output:

```json
{
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/lifeos-admin"
}
```

---

### Repository

GitHub Repository:

```text
lifeos-aws-archive
```

Primary Branch:

```text
main
```

---

### Local Project Structure

```text
lifeos-aws-archive/
├── README.md
├── cloudformation/
│   └── lifeos-s3-archive.yaml
├── docs/
│   ├── AWSbudget.md
│   ├── archive-strategy.md
│   ├── change-log.md
│   ├── media-taxonomy.md
│   ├── project-management.md
│   └── runbook.md
├── scripts/
├── logs/
└── manifests/
```

---

## Prerequisites

Required tools:

- AWS CLI v2
- Git
- VS Code
- CloudFormation
- cfn-lint

Verification:

```bash
aws --version
git --version
cfn-lint --version
```

Optional:

```bash
shellcheck --version
```

---

## Authentication

Verify AWS authentication:

```bash
aws sts get-caller-identity
```

If credentials are missing:

```bash
aws login
```

or configure credentials through IAM Identity Center or access keys.

---

## CloudFormation Validation

Before deployment:

```bash
cfn-lint cloudformation/lifeos-s3-archive.yaml
```

AWS validation:

```bash
aws cloudformation validate-template \
  --template-body file://cloudformation/lifeos-s3-archive.yaml
```

Expected result:

```text
Template validated successfully.
```

No deployment should occur until validation succeeds.

---

## CloudFormation Deployment

Deploy stack:

```bash
aws cloudformation deploy \
  --template-file cloudformation/lifeos-s3-archive.yaml \
  --stack-name lifeos-s3-archive \
  --parameter-overrides BucketName=BUCKET_NAME
```

Monitor progress:

```bash
aws cloudformation describe-stacks \
  --stack-name lifeos-s3-archive
```

Expected status:

```text
CREATE_COMPLETE
```

---

## Post-Deployment Verification

Verify bucket creation:

```bash
aws s3 ls
```

Confirm:

- Bucket exists
- Versioning enabled
- Encryption enabled
- Public access blocked

Verify versioning:

```bash
aws s3api get-bucket-versioning \
  --bucket BUCKET_NAME
```

Verify encryption:

```bash
aws s3api get-bucket-encryption \
  --bucket BUCKET_NAME
```

---

## Test Upload Procedure

Create test directory:

```bash
mkdir -p test-data
```

Create test file:

```bash
echo "LifeOS Archive Test" > test-data/hello.txt
```

Upload:

```bash
aws s3 sync \
  test-data/ \
  s3://BUCKET_NAME/test-data/ \
  --checksum-algorithm SHA256
```

Verify:

```bash
aws s3 ls \
  s3://BUCKET_NAME/test-data/
```

Expected result:

```text
hello.txt
```

---

## Test Restore Procedure

Restore test file:

```bash
aws s3 cp \
  s3://BUCKET_NAME/test-data/hello.txt \
  restored.txt \
  --checksum-mode ENABLED
```

Verify contents and checksum:

```bash
cat restored.txt
shasum -a 256 test-data/hello.txt restored.txt
```

Expected result:

```text
LifeOS Archive Test
```

---

## GoPro Archive Workflow

### Source

```text
~/Movies/GoPro
```

Current size:

```text
~178 GB
```

---

### Dry Run

Always perform a dry run first:

```bash
BUCKET=BUCKET_NAME scripts/sync_gopro_to_s3.sh
```

Review output carefully.

---

### Upload

When dry run looks correct:

```bash
BUCKET=BUCKET_NAME scripts/sync_gopro_to_s3.sh --execute
```

This guarded workflow applies the upload checksum, lock, logging, and strict post-upload checks defined by the repository.

---

### Verification

Count local files:

```bash
find ~/Movies/GoPro -type f | wc -l
```

Count remote files:

```bash
aws s3 ls \
  s3://BUCKET_NAME/video/gopro/ \
  --recursive \
  --summarize
```

Counts should be consistent.

Run the repository verifier with a restored checksum sample before considering the archive complete:

```bash
scripts/verify_gopro_sync.sh --restore-sample
```

The command must report matching local and restored SHA-256 values before local deletion.

---

## Production Photo Batch Workflow

Use the interactive helper for exported Apple Photos batches:

```bash
scripts/archive_photo_batch.sh
```

The macOS folder picker selects the exported batch. The helper proposes a
lowercase, hyphenated batch label and uses it consistently for:

- The standardized local folder name
- The S3 prefix under `photos/ingest/`
- The batch-specific manifest collection under `manifests/`
- The private verification record
- The cooling-off calendar event

To select the folder or label explicitly:

```bash
scripts/archive_photo_batch.sh \
  --source "$HOME/Pictures/Photo Exports/2025 Family" \
  --label 2025-family \
  --cooloff-days 7
```

The helper performs this guarded sequence:

1. Rejects Apple Photos library packages and requires an exported folder.
2. Confirms any local folder rename before changing it.
3. Requires at least one XMP sidecar and one supported media file.
4. Displays the source, counts, bytes, S3 prefix, sample files, and manifest destination.
5. Runs the existing guarded upload in dry-run mode.
6. Requires an explicit `y` confirmation before uploading.
7. Executes the checksum-backed upload and independently reconciles counts, bytes, and the final dry run.
8. Restores and compares SHA-256 values for both an XMP and media sample.
9. Opens the original and restored media and requires visual confirmation.
10. Generates and uploads batch-specific manifests.
11. Writes a private Markdown verification record and `.ics` cooling-off reminder under `logs/photo-batches/`.

The helper does not delete local files or Apple Photos originals. Import the
generated reminder with the command printed at completion. A calendar reminder
is a review checkpoint, not automatic deletion authorization.

Run its mocked end-to-end test without contacting AWS:

```bash
tests/test_archive_photo_batch.sh
```

---

## Manifest Generation

Generate a portable file inventory and SHA-256 manifest:

```bash
scripts/generate_manifest.sh ~/Movies/GoPro manifests gopro
```

Manifest paths are relative to the collection root so the checksums remain usable after restoration to another location.

Preview the manifest upload using `BUCKET_NAME` from `.env.private`:

```bash
scripts/upload_manifests_to_s3.sh
```

Execute the upload after reviewing the dry run:

```bash
scripts/upload_manifests_to_s3.sh --execute
```

The uploader defaults to the `gopro` collection, uploads only `gopro_*.txt` to `manifests/gopro/`, excludes `.gitkeep`, and verifies that no upload actions remain. Use `COLLECTION=photos` for another collection.

---

## Local Cleanup Procedure

No local deletion occurs until:

- Upload complete
- Verification complete
- Restore test successful
- Manifest uploaded

Recommended process:

### Step 1

Rename folder:

```text
GoPro_ARCHIVED_PENDING_DELETE
```

### Step 2

Wait at least one week.

### Step 3

Confirm successful retrieval from S3.

### Step 4

Delete local copy only if no longer needed.

---

## Monthly Operations

Monthly tasks:

- Review local storage usage
- Identify archive candidates
- Upload completed projects
- Verify recent uploads
- Review AWS costs

---

## Quarterly Operations

Quarterly tasks:

- Perform restoration test
- Review lifecycle transitions
- Review bucket size growth
- Update documentation

---

## Annual Operations

Annual tasks:

- Audit taxonomy structure
- Review disaster recovery assumptions
- Review CloudFormation templates
- Review GitHub repository organization
- Review storage costs

---

## Troubleshooting

### Credentials Missing

Check:

```bash
aws sts get-caller-identity
```

If failure occurs:

```bash
aws login
```

---

### Bucket Not Found

List buckets:

```bash
aws s3 ls
```

Verify bucket name.

---

### CloudFormation Failure

Review events:

```bash
aws cloudformation describe-stack-events \
  --stack-name lifeos-s3-archive
```

---

### Upload Interrupted

Resume safely:

```bash
BUCKET=BUCKET_NAME scripts/resume_gopro_upload.sh
```

The resume wrapper delegates to the guarded sync workflow so interrupted
uploads retain the shared lock, checksum settings, logging, and strict
post-upload checks.

---

### Verification Failure

Re-run:

```bash
BUCKET=BUCKET_NAME scripts/verify_gopro_sync.sh --restore-sample
```

Investigate reported differences before deleting local files.

---

## Cost Monitoring and Budget Alerts

Use the [AWS budget runbook](AWSbudget.md) to create and operate the initial
account-wide cost guardrail. The recommended starting configuration is a fixed,
recurring `$10` monthly cost budget with these email notifications:

- 50% actual spend
- 80% forecasted spend
- 80% actual spend
- 100% actual spend

The documented budget is not considered implemented until it appears in AWS
Budgets with all four recipients and thresholds verified. Do not attach an
automated budget action during initial adoption; alerts should trigger an
investigation rather than automatically disrupting uploads, logging, restores,
or CloudFormation operations.

Review the budget during the monthly archive and cost review. Investigate
alerts in Cost Explorer before changing lifecycle policies or deleting archive
objects. AWS Budgets is delayed alerting, not a real-time spending cap.

---

## Change Management

All infrastructure changes should follow this process:

1. Modify CloudFormation template
2. Validate template
3. Commit changes to Git
4. Push to GitHub
5. Deploy CloudFormation update
6. Verify resulting infrastructure
7. Update documentation

---

## Repository Maintenance

Commit documentation updates:

```bash
git add .
git commit -m "Update archive documentation"
git push
```

Verify status:

```bash
git status
```

Expected result:

```text
nothing to commit, working tree clean
```

---

## Success Criteria

The archive is considered operational when:

- Infrastructure deploys successfully
- Uploads complete successfully
- Restore tests succeed
- Documentation remains current
- AWS budget alerts are configured and reviewed monthly
- Cloud storage costs remain predictable
- Important data exists in multiple locations
- Future-you can operate the system using this runbook alone

---

## Revision History

| Date | Author | Notes |
| ------ | -------- | ------- |
| 2026-06-24 | Jared Godar | Initial runbook definition covering CloudFormation deployment, validation, upload procedures, manifests, restore testing, and operational maintenance. |
| 2026-06-27 | Jared Godar | Added GitHub Actions validation workflow and CI expectations. |
| 2026-06-27 | Jared Godar | Added production GoPro sync and verification script workflows replacing manual sync procedures. |
| 2026-06-28 | Jared Godar | Hardened upload checksums, locking, failure handling, manifest portability, and restore verification. |
| 2026-06-28 | Jared Godar | Updated the canonical workflow to use guarded repository scripts and expanded CI coverage. |
| 2026-06-28 | Jared Godar | Added the AWS budget setup, alert response, validation, and monthly cost-review runbook. |
| 2026-06-28 | Jared Godar | Added guarded production photo-batch orchestration, dual restore checks, private verification records, and cooling-off reminders. |
