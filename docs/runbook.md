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
  "Arn": "arn:aws:iam::123456789012:user/godarj"
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
│   ├── archive-strategy.md
│   ├── media-taxonomy.md
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
  --capabilities CAPABILITY_NAMED_IAM
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
  s3://BUCKET_NAME/test-data/
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
  restored.txt
```

Verify contents:

```bash
cat restored.txt
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
aws s3 sync \
  ~/Movies/GoPro \
  s3://BUCKET_NAME/video/gopro/ \
  --dryrun
```

Review output carefully.

---

### Upload

When dry run looks correct:

```bash
aws s3 sync \
  ~/Movies/GoPro \
  s3://BUCKET_NAME/video/gopro/
```

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

---

## Manifest Generation

Generate inventory:

```bash
find ~/Movies/GoPro \
  -type f \
  > manifests/gopro-file-list.txt
```

Generate checksums:

```bash
find ~/Movies/GoPro \
  -type f \
  -exec shasum -a 256 {} \; \
  > manifests/gopro-sha256.txt
```

Upload manifests:

```bash
aws s3 sync \
  manifests/ \
  s3://BUCKET_NAME/manifests/
```

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
aws s3 sync \
  SOURCE \
  DESTINATION
```

Sync only transfers missing or changed files.

---

### Verification Failure

Re-run:

```bash
aws s3 sync \
  SOURCE \
  DESTINATION \
  --dryrun
```

Investigate reported differences before deleting local files.

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
| 2026-06-27 | Jared Godar | Added billing alarm verification, budget review, and SNS validation procedures. |
| 2026-06-27 | Jared Godar | Added long-running upload guidance using `caffeinate`. |
| 2026-06-27 | Jared Godar | Added upload monitoring commands and resumable upload procedures. |
| 2026-06-27 | Jared Godar | Added lock file recovery procedures and AWS session expiration recovery guidance. |
| 2026-06-27 | Jared Godar | Added Recovery Point Objective (RPO), Recovery Time Objective (RTO), and storage retrieval expectations. |
| 2026-06-27 | Jared Godar | Expanded monthly, quarterly, and annual operational procedures. |
| 2026-06-27 | Jared Godar | Added disaster recovery exercise guidance and manifest verification procedures. |
| 2026-06-27 | Jared Godar | Added public portfolio sanitization by replacing operational account identifiers with placeholders including `ACCOUNT_ID`, `IAM_USERNAME`, and `BUCKET_NAME`. |
| 2026-06-27 | Jared Godar | Updated document to reflect deployed production architecture rather than initial design assumptions. |
