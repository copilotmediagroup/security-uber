# Co Pilot Security Marketplace v4.0.14 — Marketplace Activity Guard Status Feed

This build keeps the Uber-style security agency marketplace model and improves Platform Admin visibility.

## What changed
- Platform Command Center Marketplace Activity now shows guard lifecycle updates.
- Admin can see: Guard Accepted, En Route, Arrived On Site, Checking Property, Proof Uploaded, Completed, and Report Published.
- The feed reads from `job_events`, `marketplace_jobs` lifecycle timestamps, and proof rows so the activity panel updates even if one source is sparse.
- v4.0.13 build-label lock remains in place.

## SQL
No real schema change required. Optional cache refresh file:

`RUN_AFTER_V414_MARKETPLACE_ACTIVITY_GUARD_STATUS_FEED.sql`

## Test
1. Login as guard.
2. Move assigned job through Accept, En Route, Arrived, Start Patrol, Upload Proof, Complete.
3. Login as Platform Admin.
4. Command Center → Marketplace Activity should show those guard lifecycle statuses.
