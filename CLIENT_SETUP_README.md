# Co Pilot Security Marketplace v4.0.0 — Marketplace Data Foundation

This package starts the separate Uber-style / marketplace version of Co Pilot Security.

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

The first file installs the base v3 app schema/functions that the current app still needs.
The second file adds the v4 marketplace foundation.

## What v4.0.0 adds
- Platform Admin role
- Agency Admin role
- Agency signup
- Agency verification center
- Marketplace Jobs board
- Marketplace Data Foundation dashboard
- `marketplace_jobs` as the global job source of truth
- `job_events` as the audit trail
- agency approval/rejection RPCs
- agency job acceptance RPC
- client request creates open marketplace job after SQL is installed

## What is intentionally not included yet
- payments
- Stripe split payouts
- automatic closest-agency matching
- client reviews
- agency rankings
- bidding/price competition

Those come after the core data foundation is proven.
