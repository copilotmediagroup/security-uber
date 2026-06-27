# Co Pilot Security Marketplace v4.0.27

## Build
**v4.0.27 LIVE GPS ROSTER + PROPERTY VISIBILITY FIX**

This package is a complete GitHub-ready replacement package for the `security-uber` repo.

## What changed

- Agency Admin **Live GPS** is now roster-based.
- Agency Live GPS shows every approved guard signed up under that agency in the roster.
- Online/GPS-visible agency guards appear on the map.
- Agency routes appear only when the guard is in an active movement stage.
- Completed, arrived, checking, proof uploaded, and report published jobs do not keep stale route lines.
- Platform Admin visibility now includes all active guard records with coordinates and all mapped client properties.
- Platform Admin still sees marketplace jobs and active routes, but route lines remain tied to the lifecycle rules from v4.0.26.

## Preserved from earlier builds

- v4.0.26 global job state + map flow enforcement
- v4.0.25 agency proof review + client report delivery
- v4.0.24 guard job flow icon sync
- v4.0.23 badge lock
- v4.0.22 proof upload RLS app fix
- v4.0.21 profile photo save
- v4.0.20 client marketplace status tracker
- v4.0.19 no-page-reload admin sync

## SQL

No new SQL is required for v4.0.27.

Only run `RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql` if proof uploads still show a Supabase row-level security error.

## Expected badge

`v4.0.27 LIVE GPS ROSTER + PROPERTY VISIBILITY FIX`
