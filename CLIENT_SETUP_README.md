# Co Pilot Security Marketplace v4.0.15 — Badge Hard Lock + Activity Feed

This package fixes the issue where the visible badge could stay on v4.0.13 even after uploading v4.0.14.

## What changed
- Primary `BUILD` label now starts as `v4.0.15 BADGE HARD LOCK + ACTIVITY FEED`.
- Older internal badge locks are neutralized.
- A final hard-lock updates `.cp-build-badge` and `.version-mini` labels after all code loads.
- The v4.0.14 Platform Command Center Marketplace Activity feed remains included.

## SQL
No real schema change is required. Optional cache refresh only:

`RUN_AFTER_V415_BADGE_HARD_LOCK_ACTIVITY_FEED.sql`

Do not rerun older foundation SQL unless Supabase reports a missing table/function.
