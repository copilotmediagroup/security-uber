# Co Pilot Security Marketplace v4.0.2 — Client Approval Center

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
4. `RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql`

## If v4.0.0 and v4.0.1 SQL were already run
Run only:

`RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql`

## What v4.0.2 adds
- Platform Admin Client Approval Center
- Sidebar tab: Client Approvals
- Pending / Approved / Rejected / All client application tabs
- Accept Client action
- Reject Client action
- Active Clients remain separate from pending applications
- Approved clients are activated with `marketplace_role = client`
- Client signups are no longer hidden only inside the legacy Clients page

## What is intentionally not included yet
- payments
- Stripe split payouts
- automatic closest-agency matching
- client reviews
- agency rankings
- bidding/price competition

Those come after marketplace approvals, agency job acceptance, dispatch, and client status are proven.
