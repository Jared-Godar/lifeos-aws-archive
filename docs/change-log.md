# Change Log

| Date | Notes |
| --- | --- |
| 2026-06-28 | Added repository linting and completed two project hardening reviews. |

---

## 2026-06-28

- [x] Added Markdown linting and formatting configuration for the CLI and VS Code.
- [x] Added npm scripts and locked development dependencies.
- [x] Integrated CloudFormation and shell validation with repository tooling.

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
