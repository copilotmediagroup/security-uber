# Co Pilot Security Marketplace v4.0.1 — Agency Job Board

This package continues the separate Uber-style / marketplace version of Co Pilot Security.

## Important
This is **not** the v3 single-company app database.
Use the new Supabase project only:

- Supabase URL: `https://nmfvxozbptcvyaenvkxl.supabase.co`
- Publishable key is already configured in `config.js`.

Do not point this package at the old v3 Supabase project.

## SQL install order for a new Supabase
Run these in the Supabase SQL editor in this order:

1. `RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql`
2. `RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql`
3. `RUN_AFTER_V401_AGENCY_JOB_BOARD.sql`

If v4.0.0 SQL was already run, only run:

`RUN_AFTER_V401_AGENCY_JOB_BOARD.sql`

## What v4.0.1 adds
- Agency Job Board for approved licensed/certified agencies.
- Available / Accepted By Us / Declined / Locked / All tabs.
- Job detail panel before acceptance.
- Job rows show property, address/city, client notes, urgency, service type, requested time, and status.
- Agency decline RPC: `cp_agency_decline_marketplace_job`.
- Decline records into `marketplace_job_claims` and `job_events` without changing the global open job status.

## What is intentionally not included yet
- payments
- Stripe split payouts
- automatic closest-agency matching
- client reviews
- agency rankings
- bidding/price competition
