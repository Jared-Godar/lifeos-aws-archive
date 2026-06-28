# LifeOS AWS Archive

Personal Infrastructure-as-Code project for long-term archival, backup, and organization of digital assets using AWS and CloudFormation.

## Overview

LifeOS AWS Archive is a personal cloud archival platform designed to support a broader digital organization initiative spanning:

- macOS file organization
- Obsidian knowledge management
- personal media preservation
- photo and video archives
- document retention
- disaster recovery
- long-term cloud storage

The initial implementation focuses on Infrastructure-as-Code (IaC) deployment of secure AWS S3 storage using CloudFormation.

## Project Goals

### Primary Goals

- Preserve important digital assets
- Create off-device backups of irreplaceable media
- Establish repeatable Infrastructure-as-Code practices
- Develop a maintainable personal cloud archive
- Build a public portfolio demonstrating AWS skills

### Secondary Goals

- Reduce local storage consumption
- Support future media organization efforts
- Enable lifecycle management and archival storage tiers
- Provide a foundation for automation and data-management workflows

## Architecture

### Current Components

- AWS S3 Archive Bucket
- AWS CloudFormation Template
- GitHub Version Control
- AWS CLI Deployment Workflow
- Versioning, encryption, public-access blocking, and lifecycle transitions
- Guarded and resumable GoPro synchronization
- Portable manifest generation and restored-sample integrity verification
- CloudFormation, shell, and Markdown validation

### Planned Components

- Automated media ingestion
- Cost monitoring
- Event notifications

## Repository Structure

```text
lifeos-aws-archive/

├── cloudformation/
│   └── lifeos-s3-archive.yaml
│
├── docs/
│   ├── archive-strategy.md
│   ├── change-log.md
│   ├── images/
│   │   └── trello-board.png
│   ├── media-taxonomy.md
│   ├── project-management.md
│   └── runbook.md
│
├── scripts/
│   ├── generate_manifest.sh
│   ├── resume_gopro_upload.sh
│   ├── sanitize_private_values.sh
│   ├── sync_gopro_to_s3.sh
│   ├── upload_manifests_to_s3.sh
│   └── verify_gopro_sync.sh
│
├── logs/
│   └── .gitkeep
│
└── README.md
```

## Project Management Case Study

The [project management case study](docs/project-management.md) documents the
Trello workflow, label taxonomy, verified milestones, and the engineering
decisions that keep archive operations recoverable and auditable.

Current verified outcomes include:

- 63 GoPro files totaling approximately 178 GiB, including a successful
  SHA-256 restore and playback comparison
- 318 photo-pilot files totaling 533,165,130 bytes (approximately 533 MB),
  including successful XMP and JPEG SHA-256 restores
- portable file inventories and SHA-256 manifests stored separately in S3
- dry-run defaults, no-delete safeguards, restore testing, and lifecycle
  controls

## Technology Stack

### Cloud

- AWS S3
- AWS CloudFormation
- AWS CLI

### Development

- VS Code
- Git
- GitHub

### Platform

- macOS
- Apple Silicon

## Deployment

Validate the CloudFormation template:

```bash
aws cloudformation validate-template \
  --template-body file://cloudformation/lifeos-s3-archive.yaml
```

Deploy the stack:

```bash
aws cloudformation deploy \
  --template-file cloudformation/lifeos-s3-archive.yaml \
  --stack-name lifeos-s3-archive \
  --parameter-overrides BucketName=BUCKET_NAME
```

## Roadmap

### Phase 1 – Infrastructure Foundation

- [x] Create GitHub repository
- [x] Configure AWS CLI
- [x] Create CloudFormation template
- [ ] Deploy archive bucket
- [ ] Validate access controls

### Phase 2 – Media Archive

- [ ] Upload GoPro archive
- [ ] Upload photo archive
- [x] Add manifest generation tooling
- [x] Add restored-sample integrity verification

### Phase 3 – Automation

- [x] Guarded and resumable synchronization scripts
- [x] Lifecycle policies
- [x] Glacier transition configuration
- [ ] Cost reporting

### Phase 4 – Digital Organization Integration

- [ ] Obsidian integration
- [ ] macOS organizational workflow integration
- [ ] Knowledge-management archive strategy
- [ ] Disaster-recovery procedures

## Future Expansion

The long-term vision is for this repository to become the cloud archival component of a broader LifeOS ecosystem integrating:

- macOS organizational workflows
- Obsidian knowledge management
- GTD project management
- digital asset preservation
- cloud-based backup and disaster recovery
- automation and personal infrastructure

## Author

Jared Godar

Data Engineer | Veteran | AWS Practitioner

This repository serves as both a practical archival solution and an ongoing demonstration of cloud infrastructure, automation, documentation, and operational engineering practices.
