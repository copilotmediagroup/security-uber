# Co Pilot Security Marketplace v4.0.12 — Platform Lifecycle Sync Fix

This is a GitHub-ready replacement package for the `security-uber` marketplace project.

## What changed
- Platform Command Center now follows the guard marketplace job lifecycle.
- Platform Admin sees guard accepted, en route, arrived, in progress, proof uploaded, and completed statuses.
- Command Center auto-refreshes while open so guard actions appear on the admin side.
- Job Ownership table and Marketplace Activity feed now read from `marketplace_jobs`, `job_events`, and proof records.

## SQL
If you already ran v4.0.11, run only:

`RUN_AFTER_V412_PLATFORM_LIFECYCLE_SYNC_FIX.sql`

This is only a schema-cache refresh. No new core tables are required.
