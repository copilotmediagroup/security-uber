# Co Pilot Security Marketplace v4.0.20

## Build
**v4.0.20 CLIENT MARKETPLACE STATUS TRACKER**

This is a complete GitHub-ready replacement package for the `security-uber` repo.

## Important
Do not use Bolt AI prompts. Upload/replace files through GitHub/Bolt import.

## Supabase
Use the marketplace Supabase project only:

`https://nmfvxozbptcvyaenvkxl.supabase.co`

The publishable key is already inside `config.js`.

## SQL
No new SQL is required for v4.0.20.

Keep using:

`RUN_IF_NEEDED_ALL_SQL_V400_TO_V417_CONSOLIDATED.sql`

Only run it if the Supabase project is fresh or a missing table/RPC/function error appears.

## What v4.0.20 adds
Client Marketplace Status Tracker.

The client now gets a clear Uber-style tracker that reads the shared marketplace lifecycle:

1. Open Marketplace
2. Agency Accepted
3. Guard Assigned
4. Guard Accepted
5. En Route
6. Arrived
7. Checking Property
8. Proof Uploaded
9. Completed
10. Report Published

## Preserved from v4.0.19
- No aggressive Platform Admin page reload.
- No full dashboard refresh timer.
- Quiet admin activity sync remains.
- Manual Refresh still works.

## Badge
Expected badge:

**v4.0.20 CLIENT MARKETPLACE STATUS TRACKER**
