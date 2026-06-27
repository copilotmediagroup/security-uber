# Co Pilot Security Marketplace v4.0.18 — Consolidated Package

This is the latest working **Security Uber / marketplace** build consolidated to fewer than 20 files for easy upload into GitHub/Bolt.

## Current build
**v4.0.18 ADMIN LIVE ACTIVITY STATUS SYNC**

This build keeps the v4.0.17 server-root entry lock fix and adds a stronger Platform Admin Marketplace Activity sync layer.

## What changed in v4.0.18
- Platform Admin Marketplace Activity now builds one live feed from `job_events`, `marketplace_jobs` lifecycle timestamps, proof uploads, patrol report rows, and local report-publish audit rows.
- The admin feed clearly covers: Guard accepted job → En route → Arrived → Checking property → Proof uploaded → Completed → Report published.
- Platform Command Center now auto-refreshes every 6 seconds while the platform admin dashboard is open, plus refreshes on browser focus/visibility.
- Report publish now attempts to sync the marketplace job to `report_published` and write a `job_events` row when permissions allow it; if Supabase blocks it, the UI still shows the local publish event.
- Badge hard-lock updated to: `v4.0.18 ADMIN LIVE ACTIVITY STATUS SYNC`.

## Supabase
Use the marketplace Supabase only:

- URL: `https://nmfvxozbptcvyaenvkxl.supabase.co`
- Publishable key is already in `config.js`

## SQL
This package still includes the existing all-in-one SQL file:

`RUN_IF_NEEDED_ALL_SQL_V400_TO_V417_CONSOLIDATED.sql`

No new SQL is required for v4.0.18. Do **not** rerun SQL unless the Supabase project is fresh or a table/RPC/function error appears.

## Main app flow
Client requests job → job goes to open marketplace → approved agency accepts → job locks to agency → agency assigns its own guard → guard works lifecycle → Platform Admin sees activity/status/map globally.
