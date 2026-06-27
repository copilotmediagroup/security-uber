# Co Pilot Security Marketplace v4.0.8 — Agency Live GPS Boot Fix

This is a full GitHub-ready replacement package for the separate v4 Security Uber / marketplace project.

## What this fixes

v4.0.7 could freeze on **Preparing app** during startup. The cause was a Live GPS override that accidentally called itself because JavaScript function declarations are hoisted. This package fixes that boot recursion and keeps the Agency Live GPS route visibility work.

## Included behavior

- Agency Admin Live GPS still shows agency guards.
- Assigned agency guard route remains linked to the accepted marketplace job.
- Startup now has a failsafe so the app does not sit on the loading screen forever.

## SQL

No schema change is required.

Optional cache refresh file:

1. `RUN_AFTER_V408_AGENCY_LIVE_GPS_BOOT_FIX.sql`

Run it only if you want to refresh PostgREST schema cache.
