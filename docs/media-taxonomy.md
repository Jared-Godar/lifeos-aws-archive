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

Once a top-level storage category is established and populated, it should rarely change. Stable paths make automation, documentation, and retrieval easier.

### Human Readability

Storage locations should be understandable without requiring additional documentation.

### Event-Based Organization

Photos, videos, and recordings should generally be grouped by event rather than device.

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

---

## S3 Archive Structure

```text
s3://lifeos-archive/

photos/
│
├── camera-imports/
├── processed/
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
└── edited/
    └── YYYY/

audio/
│
├── music/
│
├── concert-recordings/
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

Destination:

```text
video/gopro/
```

---

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

---

### Historical Photo Collections

Local source:

```text
~/Pictures
```

Contains:

- Travel photography
- Family photos
- Nature photography
- Event photography
- Camera dumps

Destination:

```text
photos/events/
```

---

### Obsidian Vaults

Destination:

```text
obsidian/vault-backups/
```

Purpose:

- Periodic vault snapshots
- Disaster recovery
- Historical version retention

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

---

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

---

### File Names

Preferred:

```text
2026-06-24_mvet-performance_001.mp4
```

Avoid:

```text
IMG_0001.mp4
```

when creating processed or exported files.

Original files should remain unmodified.

---

## Archive Rules

### Preserve Originals

Original files should never be renamed, modified, or deleted until upload verification is complete.

### Generate Manifests

Large uploads should be accompanied by:

- SHA256 manifests
- Upload logs
- Verification reports

### Verify Before Deleting

Cloud copies must be verified before removing local source files.

### No Secrets

The archive bucket must never contain:

- Passwords
- API keys
- AWS credentials
- SSH private keys
- Authentication tokens

### Infrastructure as Code

Changes to archive infrastructure should be made through CloudFormation whenever practical.

---

## Future Expansion

Planned future additions include:

- Glacier lifecycle policies
- Automated upload workflows
- Integrity validation automation
- Cost reporting
- Media indexing
- Metadata extraction
- Searchable archive inventory

---

## Revision History

| Date | Author | Notes |
| --- | --- | --- |
| 2026-06-24 | Jared Godar | Initial taxonomy definition |
