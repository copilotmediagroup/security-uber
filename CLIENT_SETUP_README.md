# Co Pilot Security Marketplace v4.0.4 — Marketplace Role Cleanup

This is the standalone Uber-style marketplace version, not the old v3 single-company app.

## New Supabase
Use only:

- `https://nmfvxozbptcvyaenvkxl.supabase.co`

The publishable key is already configured in `config.js`.

## What changed in v4.0.4

- Removed the public **Legacy Dispatch** login option.
- Old v3 `admin` / dispatch accounts are normalized to **Platform Admin** for marketplace compatibility.
- Platform Admin is the Co Pilot marketplace owner/operator role.
- Agency Admin is the licensed security company role.
- Agency Dispatch wording is renamed to **Agency Job Management**.
- Platform Admin no longer sees old dispatch-board / pending-dispatch navigation.
- Client jobs still flow to the open marketplace.
- The accepting agency assigns its own guards after accepting the job.

## Correct marketplace flow

Client submits job → job appears in open marketplace → approved agency accepts → job locks to that agency → agency assigns its own guard → guard completes job → proof/report returns to client through the platform.

## SQL order

If you already ran v4.0.0 through v4.0.3 SQL, run only:

1. `RUN_AFTER_V404_MARKETPLACE_ROLE_CLEANUP.sql`

For a fresh Supabase, run all SQL in this order:

1. `RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql`
2. `RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql`
3. `RUN_AFTER_V401_AGENCY_JOB_BOARD.sql`
4. `RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql`
5. `RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql`
6. `RUN_AFTER_V404_MARKETPLACE_ROLE_CLEANUP.sql`

## Not added yet

- No payments
- No Stripe
- No subscriptions
- No bidding
- No rankings
- No closest-agency auto-matching
