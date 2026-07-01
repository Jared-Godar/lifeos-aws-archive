# Contributing

Thanks for helping improve LifeOS AWS Archive.

## Before Opening a Pull Request

1. Create a focused branch and keep the change narrowly scoped.
2. Use placeholders for AWS account IDs, bucket names, usernames, and local
   paths. Never commit credentials, manifests, archive contents, or runtime
   logs.
3. Run the repository validation suite:

   ```bash
   uv run scripts/validate_repo.sh
   ```

4. Explain the operational and cost implications of infrastructure changes.
5. Update the README or runbook when behavior or operator steps change.

By contributing, you confirm that you have the right to submit the work and
agree that it will be distributed under the Mozilla Public License 2.0.
