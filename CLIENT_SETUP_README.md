# Co Pilot Security Marketplace v4.0.3 — Agency Dispatch + Client Location Fix

This is the separate Uber-style marketplace version of Co Pilot Security.

## Important
This is not the old v3 single-company app database.
Use the new Supabase project only:

- Supabase URL: `https://nmfvxozbptcvyaenvkxl.supabase.co`
- Publishable key is already configured in `config.js`.

## What v4.0.3 adds

- Client signup now requires location:
  - Property / business name
  - Service address
  - City
  - State
  - ZIP
- Client Approval Center shows the submitted location before Platform Admin approves the client.
- Approving a client creates/updates the active client record and creates/updates a primary property record.
- Agency Dispatch board for accepted marketplace jobs.
- Agency Admin can assign one of its own agency guards.
- Assignment updates `marketplace_jobs.assigned_guard_id` and `marketplace_jobs.current_status = guard_assigned`.
- Marketplace Jobs detail shows accepted agency and assigned guard.

## SQL install order

For a fresh Supabase project run:

1. `RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql`
2. `RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql`
3. `RUN_AFTER_V401_AGENCY_JOB_BOARD.sql`
4. `RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql`
5. `RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql`

If you already ran v4.0.0, v4.0.1, and v4.0.2 SQL, run only:

`RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql`

## Not included yet

- payments
- Stripe
- subscriptions
- closest-agency auto-matching
- bidding
- agency rankings
