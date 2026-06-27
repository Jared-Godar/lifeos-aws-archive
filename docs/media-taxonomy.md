# Media Taxonomy

## Purpose

This document defines the organizational structure for long-term storage of digital assets within the LifeOS AWS archive environment.

The goals of this taxonomy are to:

- Preserve important digital assets
- Maintain a predictable storage structure
- Support future automation workflows
- Align cloud storage with the broader LifeOS organizational system
- Simplify backup, retrieval, and disaster recovery operations
- Prevent ad-hoc folder sprawl over time

---

## Design Principles

### Stability Over Perfection

Once a top-level storage category is established and populated, it should rarely change.

Stable paths make automation, documentation, lifecycle management, and retrieval easier.

### Human Readability

Storage locations should be understandable without requiring additional documentation.

A folder path should remain interpretable decades later even if the originating hardware or software no longer exists.

### Event-Based Organization

Photos, videos, and recordings should generally be grouped by event rather than by capture device.

Preferred:

```text
2026-07-04_independence-day
2026-06-24_mvet-performance
2025-11-15_new-orleans-trip
```

Avoid using device-only folders as permanent archival destinations:

```text
iphone/
camera-roll/
sd-card-03/
```

### Meaning Over Device

Folder hierarchy should answer:

> What is this?

Metadata should answer:

> When, where, how, and with whom?

### Automation Friendly

Folder names should avoid spaces and special characters whenever practical.

Recommended:

```text
2026-06-24_mvet-performance
```

Avoid:

```text
MVET Performance June 24th!!!
```

### Preserve Originals

Original media should remain unmodified whenever practical.

Derivative files should never replace source material.

Preferred hierarchy:

```text
Original
↓
Working Copy
↓
Edited Master
↓
Distribution Export
```

---

## S3 Archive Structure

```text
s3://lifeos-archive/

photos/
│
├── ingest/
│   ├── iphone/
│   ├── camera-imports/
│   └── scanner/
│
├── processed/
│
└── events/
    └── YYYY/
        └── YYYY-MM-DD_event-name/

video/
│
├── gopro/
│   └── YYYY/
│       └── YYYY-MM-DD_event-name/
│
├── iphone/
│   └── YYYY/
│
├── edited/
│   └── YYYY/
│
└── projects/
    └── project-name/

audio/
│
├── music/
│
├── concert-recordings/
│
├── rehearsals/
│
├── field-recordings/
│
└── voice-recordings/

documents/
│
├── finance/
│
├── health/
│
├── career/
│
├── legal/
│
├── vehicle/
│
└── personal/

obsidian/
│
├── vault-backups/
│
└── exports/

archive/
│
├── google-drive-import/
│
├── legacy-computers/
│
├── old-backups/
│
└── miscellaneous/

manifests/
│
├── uploads/
│
├── verification/
│
└── inventory/

logs/
│
├── upload-logs/
│
└── audit-logs/
```

---

## Preservation Classes

### Tier 0 — Irreplaceable

Examples:

- family photographs
- military records
- mission photography
- original recordings
- historical documents

Storage policy:

- local copy
- S3 Standard
- Glacier Deep Archive
- offline copy when practical

### Tier 1 — Important but Reproducible

Examples:

- edited videos
- project assets
- exports
- deliverables
- work products

Storage policy:

- local copy
- S3 Standard
- Glacier optional

### Tier 2 — Disposable

Examples:

- downloads
- installers
- temporary exports
- caches
- scratch files

Storage policy:

- local storage only
- delete when no longer useful

---

## Archive Lifecycle

Objects generally move through the following stages:

```text
capture
    ↓
ingest
    ↓
verify
    ↓
classify
    ↓
archive
    ↓
glacier
```

Example:

```text
GoPro SD Card
    ↓
~/Movies/GoPro
    ↓
video/gopro/
    ↓
manifest verification
    ↓
video/events/2026/2026-07-04_mvet-performance/
    ↓
Glacier lifecycle transition
```

---

## Current Known Data Sources

### GoPro Archive

Local source:

```text
~/Movies/GoPro
```

Approximate size:

```text
178 GB
```

Current destination:

```text
video/gopro/
```

Notes:

- Current location serves as the ingest zone.
- Future automation may classify content into event-based locations.

### Photos Library

Local source:

```text
~/Pictures/Photos Library.photoslibrary
```

Approximate size:

```text
18 GB
```

Destination:

```text
photos/
```

### Historical Photo Collections

Local source:

```text
~/Pictures
```

Contains:

- travel photography
- family photos
- nature photography
- event photography
- camera imports

Destination:

```text
photos/events/
```

### Obsidian Vaults

Destination:

```text
obsidian/vault-backups/
```

Purpose:

- periodic vault snapshots
- disaster recovery
- historical version retention

---

## Naming Standards

### Years

```text
YYYY
```

Example:

```text
2026
```

### Events

```text
YYYY-MM-DD_event-name
```

Examples:

```text
2026-07-04_independence-day
2026-06-24_mvet-performance
2025-11-15_new-orleans-trip
```

### File Names

Preferred:

```text
2026-06-24_mvet-performance_001.mp4
```

Preferred extended format:

```text
20260704_193000_GOPRO_MVET250TH_001.MP4
```

Avoid for generated, processed, or exported content:

```text
IMG_0001.mp4
GOPR1043.MP4
DSC_3872.JPG
```

Original source material should remain unmodified.

---

## Archive Rules

### Preserve Original Files

Original files should never be renamed, modified, or deleted until upload verification is complete.

### Generate Manifests

Large uploads should be accompanied by:

- SHA256 manifests
- upload logs
- verification reports
- object inventories

### Verify Before Deleting

Cloud copies must be verified before removing local source files.

### No Secrets

The archive bucket must never contain:

- passwords
- API keys
- AWS credentials
- SSH private keys
- authentication tokens

### Infrastructure as Code

Changes to archive infrastructure should be made through CloudFormation whenever practical.

---

## Future Expansion

Planned future additions include:

- Glacier lifecycle policies
- automated upload workflows
- integrity validation automation
- cost reporting
- media indexing
- metadata extraction
- searchable archive inventory
- EXIF extraction
- GPS indexing
- OCR extraction
- speech-to-text transcription
- face clustering
- semantic tagging
- event correlation
- AI-assisted search

---

## Revision History

| Date | Author | Notes |
| --- | --- | --- |
| 2026-06-24 | Jared Godar | Initial taxonomy definition |
| 2026-06-27 | Jared Godar | Added preservation classes, archive lifecycle model, metadata strategy, and future automation support |
