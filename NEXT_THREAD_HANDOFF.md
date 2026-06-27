# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app.

Do **not** suggest Bolt AI prompts. The user has no Bolt tokens. All future changes must be complete **GitHub-ready ZIP replacement packages**.

This is separate from the old v3 single-company app called **Co Pilot Security OS**.

## Current repo
`security-uber`

## Supabase
`https://nmfvxozbptcvyaenvkxl.supabase.co`

Publishable key is already inside `config.js`.

## Current latest build
**v4.0.27 LIVE GPS ROSTER + PROPERTY VISIBILITY FIX**

## Current marketplace model

Co Pilot Security is the platform/software marketplace layer, not the licensed security provider.

Client requests patrol job → open marketplace → approved licensed agency accepts → job locks to that agency → agency assigns its own guard → guard works lifecycle → agency reviews proof and publishes report → client sees tracker/report → platform admin audits marketplace.

## Important latest fix

v4.0.27 fixed the Live GPS visibility model:

- Agency Admin Live GPS is now roster-based, not job-only.
- Agency Admin sees every approved guard signed up under that agency in the roster.
- Online/GPS-visible agency guards appear on the map.
- Agency routes appear only for active movement jobs.
- Completed/arrived/checking/proof/report stages do not keep stale guard-to-property route lines.
- Platform Admin visibility now includes all active guard records with coordinates and all mapped client properties.
- Compact professional map cards remain:
  - Guard card: company name, guard name, guard current address.
  - Client/property card: client name, property name, address.

## Preserved fixes

- v4.0.26 global job state + map flow enforcement
- v4.0.25 agency proof review + client report delivery
- v4.0.24 guard job flow icon sync
- v4.0.23 badge lock
- v4.0.22 proof upload RLS app fix
- v4.0.21 profile photo save
- v4.0.20 client marketplace status tracker
- v4.0.19 quiet admin sync/no page reload

## SQL

No new SQL is required for v4.0.27.

Only run `RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql` if proof uploads still show a Supabase RLS error.

## Next likely direction

After testing v4.0.27:

1. Confirm Agency Live GPS shows agency guard roster even before active jobs.
2. Confirm online guards appear on Agency map.
3. Confirm routes only show while a guard is actually moving toward a job.
4. Confirm Platform Admin sees all mapped guards and all mapped client properties.
5. Then build marketplace pricing/platform fee logic and agency earnings dashboard.
