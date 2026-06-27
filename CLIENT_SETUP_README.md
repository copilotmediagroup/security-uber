# Co Pilot Security Marketplace v4.0.9 — Platform Command Center Map

This package upgrades the Platform Admin dashboard into the whole-marketplace command center.

## What changed

- Platform Admin dashboard now shows a large marketplace map-style command center.
- Map shows client properties, open marketplace jobs, accepted jobs, online guards, and assigned guard routes when GPS/location data is available.
- Platform Admin can filter by company and job status.
- Company Activity panel shows approved agencies, online guards, total guards, accepted jobs, and assigned jobs.
- Job Ownership table shows the accepted company and assigned guard for every marketplace job.

## Marketplace rule

Co Pilot Security is platform oversight only. Agencies accept open jobs and assign their own guards.

## SQL

No schema change is required. Optional cache refresh file included:

`RUN_AFTER_V409_PLATFORM_COMMAND_CENTER_MAP.sql`
