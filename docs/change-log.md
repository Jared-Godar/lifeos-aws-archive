# Change Log

|   Date   | Notes |
| :------: | :---- |
| 20250628 |       |

---

## 20250628

- [x] Added markdownlint/prettier on save to `.vscode {} settings.json`
- [ ] CLI / pre-commit: For automatic corrections in CI or pre-commit:
  - [ ] Install CLI tools: - [ ] `npm install -D remark-cli remark-preset-lint-recommended` - [ ] cd '/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive' && node -v && npm -v - [ ]
        Add to .pre-commit-config.yaml or your pre-commit hooks so commits auto-lint/fix.

```bash
npm install -D remark-cli remark-preset-lint-recommended

cd '/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive' && node -v && npm -v

which brew || true && brew --version || true
```

---

## TODO:

1. **High** — _Lifecycle rules miss the actual archive paths._ Upload scripts use video/gopro/, while CloudFormation only transitions media/. The taxonomy also uses documents/ and archive/google-drive-import/, but lifecycle rules target different prefixes. Most archived data will remain in S3 Standard indefinitely. See [template (line 49)](/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive/cloudformation/lifeos-s3-archive.yaml:49) and [sync script (line 31)](/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive/scripts/sync_gopro_to_s3.sh:31).
2. **High** — _“Verification” is not integrity verification._ It compares counts and aws s3 sync --dryrun; the restore test only confirms that a file exists after download. No SHA-256 comparison occurs, despite manifests being generated. Corruption could therefore go undetected before local deletion. See [verify_gopro_sync.sh (line 134)](/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive/scripts/verify_gopro_sync.sh:134).
3. **Medium** — _Documented deployment commands omit a required parameter._ BucketName has no default, so the first deployment commands in both the README and runbook will fail without --parameter-overrides BucketName=.... See [README.md (line 107)](/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive/README.md:107).
4. **Medium** — _Upload verification failures still return success._ Remaining uploads or count mismatches only produce warnings; the script reaches “Complete” with exit status 0. Automation—or a tired human at 3 a.m.—can interpret an incomplete archive as successful. See [sync_gopro_to_s3.sh (line 186)](/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive/scripts/sync_gopro_to_s3.sh:186).
5. **Medium** — _The lock can be removed by a competing invocation._ The exit trap is installed before checking the lock. A second process sees the existing lock, exits, and deletes the first process’s lock. The check-and-create operation is also non-atomic. See [sync_gopro_to_s3.sh (line 72)](/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive/scripts/sync_gopro_to_s3.sh:72).
6. **Low** — _Manifests embed absolute local paths._ That makes later shasum -c restoration checks non-portable and exposes workstation paths in uploaded manifests. See [generate_manifest.sh (line 33)](/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive/scripts/generate_manifest.sh:33).
7. **Low** — _Restore sampling breaks on object keys containing spaces._ awk '{print $4}' truncates such keys. See [verify_gopro_sync.sh (line 158)](/Users/example/Library/Mobile Documents/com~apple~CloudDocs/LifeOS/02 Projects/AWS Archive Migration/code/lifeos-aws-archive/scripts/verify_gopro_sync.sh:158).
