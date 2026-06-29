# LifeOS Archive Strategy

## Purpose

The LifeOS Archive project provides a long-term, cloud-based preservation system for important personal digital assets.

The archive serves as a disaster recovery platform, historical record, and centralized storage repository for media, documents, knowledge management assets, and personal records accumulated across multiple devices and services.

Primary objectives:

- Prevent accidental loss of irreplaceable data
- Consolidate fragmented storage locations
- Establish repeatable backup procedures
- Create verifiable and auditable archive workflows
- Support future automation and media management projects
- Maintain a searchable and well-organized historical record

## Scope

The archive is intended to preserve the following categories of data.

### Photos

- Apple Photos exports
- Camera imports
- Travel photography
- Family photographs
- Historical image collections
- Event photography

### Video

- GoPro recordings
- iPhone video
- Edited video projects
- Future drone footage or external camera footage

### Audio

- Zoom H2essential recordings
- Concert recordings
- Music projects
- Voice recordings
- Other original audio captures

### Documents

- Financial records
- Tax documents
- Legal records
- Vehicle records
- Medical records
- Career materials
- Professional certifications

### Knowledge Management

- Obsidian vault backups
- Project exports
- Research archives
- Personal documentation
- System design notes

### Legacy Data

- Historical Google Drive exports
- Archived computer backups
- Retired project material
- Legacy media collections

## Data Classification

### Tier 1 - Irreplaceable

Loss would be permanent or emotionally significant.

Examples:

- Family photographs
- Travel photographs
- Personal videos
- Historical recordings
- Original documents
- Important personal records

Storage requirements:

- Local working copy when practical
- Cloud archive copy
- Versioning enabled
- Restoration process documented

### Tier 2 - Difficult to Replace

Recoverable, but costly or time-consuming.

Examples:

- Project files
- Professional portfolio work
- Obsidian vaults
- Creative work
- Audio/video editing projects

Storage requirements:

- Local working copy while active
- Cloud archive copy
- Periodic verification

### Tier 3 - Easily Recreated

Can be regenerated or reacquired from source systems.

Examples:

- Application installers
- Temporary exports
- Cached data
- Downloaded reference material still available elsewhere

Storage requirements:

- Archive only when convenient or project-relevant

## Preservation Philosophy

The archive prioritizes preservation over optimization.

Original files should not be renamed, modified, compressed, or transformed before archival unless there is a specific preservation reason.

Archive copies should preserve:

- Original filenames
- Original timestamps when possible
- Original directory structures where useful
- Source context

Derived or processed files should be stored separately from original source files.

## Storage Strategy

The archive uses AWS S3 as the primary cloud storage layer.

CloudFormation is used to define infrastructure so that the environment is reproducible, reviewable, and version-controlled.

Initial storage behavior:

- Uploads land in S3 Standard storage
- Lifecycle policies transition data to lower-cost archive classes over time
- Manifests and verification files remain more readily accessible
- Versioning remains enabled for protection against accidental overwrite or deletion

## Lifecycle Strategy

Lifecycle policies should balance cost, recoverability, and operational simplicity.

Recommended approach:

| Data Type | Initial Class | Later Class | Deep Archive |
| --- | --- | --- | --- |
| Active archive uploads | S3 Standard | Glacier Instant Retrieval | Glacier Deep Archive |
| Documents archive | S3 Standard | Standard-IA / Glacier Instant Retrieval | Glacier Deep Archive |
| Media archive | S3 Standard | Glacier Instant Retrieval | Glacier Deep Archive |
| Manifests | S3 Standard | Standard-IA | Usually not deep archive |

Large media should remain in S3 Standard long enough to allow verification and near-term retrieval before transition.

## Verification Standards

Uploads should be considered complete only after:

1. Upload command completes successfully
2. Object counts are reviewed
3. Dry-run sync shows no missing files
4. Spot-check restoration succeeds
5. Manifest is generated for critical collections
6. Manifest is uploaded to the archive

No local deletion should occur before verification.

## Local Deletion Policy

Local files may be deleted or moved to external storage only after:

- Cloud upload is complete
- Verification is complete
- At least one manifest exists
- Restore test succeeds
- The data is no longer actively needed locally

Preferred local cleanup process:

1. Upload to S3
2. Verify upload
3. Rename local folder with `_ARCHIVED_PENDING_DELETE`
4. Wait several days
5. Delete only after confirming no active need remains

## Security Requirements

The archive must never contain:

- Passwords
- Password-manager exports
- AWS credentials
- SSH private keys
- API keys
- Authentication tokens
- Secrets files
- Unredacted sensitive exports intended only for local use

Required controls:

- S3 public access blocked
- Server-side encryption enabled
- Versioning enabled
- Infrastructure managed through CloudFormation
- Credentials excluded from Git

## GitHub Repository Rules

The GitHub repository may contain:

- CloudFormation templates
- Shell scripts
- Documentation
- Runbooks
- Sanitized examples
- Empty placeholder files such as `.gitkeep`

The GitHub repository should not contain:

- Actual media files
- Personal manifests with sensitive filenames
- Logs containing private local paths
- AWS credentials
- Private keys
- Exported account data
- Medical, financial, or legal documents

## Disaster Recovery Goals

### Recovery Point Objective

Maximum acceptable data loss:

- Active projects: 7 days
- Routine archives: 30 days
- Irreplaceable media: archive as soon as practical after import

### Recovery Time Objective

Target restoration time:

- Critical documents: 24 hours
- Project files: 24-48 hours
- Large media collections: 72 hours or longer depending on storage class

## Cost Controls

Cost should be controlled through:

- Configuring the account-wide guardrail in the [AWS budget runbook](AWSbudget.md)
- Monitoring actual and forecasted budget alerts
- Lifecycle policies
- Avoiding unnecessary duplicate uploads
- Using manifests before re-uploading large collections
- Moving cold media to archive classes
- Reviewing storage reports periodically

Large uploads should be tested on small folders before bulk media transfer.
Production Apple Photos exports should use `scripts/archive_photo_batch.sh` so
each batch receives the same naming, upload, reconciliation, dual-restore,
manifest, verification-record, and cooling-off workflow.

## Operational Cadence

Monthly:

- Review local storage pressure
- Review actual and forecasted AWS spend against the monthly budget
- Review pending archive candidates
- Upload newly finalized files
- Confirm recent uploads

Quarterly:

- Perform restore test
- Review S3 storage usage
- Review lifecycle rules
- Update documentation

Annually:

- Audit archive taxonomy
- Review disaster recovery assumptions
- Confirm repository documentation is current
- Reassess cost and storage classes

## Success Criteria

The archive is considered successful when:

- Critical media exists in more than one location
- Important files are organized under stable prefixes
- Upload procedures are repeatable
- Restore procedures are documented and tested
- Cloud infrastructure is version-controlled
- Local storage pressure is reduced without reckless deletion
- The system can be understood by future-you without reconstructing the reasoning from memory

## Future Roadmap

Planned enhancements:

- Automated manifest generation
- Upload helper scripts
- Restore helper scripts
- Configure the documented AWS budget alerts
- Cost-reporting workflow beyond the initial monthly budget
- CloudWatch or S3 inventory integration
- Metadata extraction
- Searchable archive index
- Periodic Obsidian vault backups
- GitHub Actions validation for CloudFormation templates
