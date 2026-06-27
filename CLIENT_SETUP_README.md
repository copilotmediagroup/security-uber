# Co Pilot Security Marketplace v4.0.6 — Agency Assignment UI Fix

This is a GitHub-ready replacement package for the separate Uber-style security agency marketplace.

## What this patch fixes

- The Agency Job Management page now has one clear guard assignment path.
- The accepted jobs table no longer has a second Assign Guard button.
- The table button now only opens/manages the selected job detail.
- The right-side Agency Job Detail panel is the only place where the agency selects and assigns a guard.
- The guard dropdown now renders valid option tags and stores the selected guard correctly.

## Marketplace model

Clients request jobs. Approved agencies accept open marketplace jobs. The accepted job locks to that agency. The agency then assigns one of its own guards. Co Pilot remains the software/platform layer.

## SQL

No schema change is required for this build. An optional no-op schema reload file is included:

`RUN_AFTER_V406_AGENCY_ASSIGNMENT_UI_FIX.sql`

Run it only if you want to refresh Supabase PostgREST schema cache.
