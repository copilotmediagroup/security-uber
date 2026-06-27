# Co Pilot Security Marketplace v4.0.28 — Universal Map Card System

This is a complete GitHub-ready replacement package for the **security-uber** repo.

## Current build
**v4.0.28 UNIVERSAL MAP CARD SYSTEM**

## What changed
- The compact professional **Agency Admin map card** is now the universal map card style across every map.
- Platform Admin maps, Agency Admin maps, Guard maps, and Client maps now use the same card structure.
- Guard cards show:
  - Company name
  - Guard name
  - Guard current address
- Client/property cards show:
  - Client name
  - Property name
  - Property address

## Preserved from prior builds
- v4.0.27 Agency Live GPS roster + Platform Admin property visibility
- v4.0.26 global job state + map flow route enforcement
- v4.0.25 agency proof review + client report delivery
- v4.0.24 guard job-flow icon sync
- v4.0.23 badge lock
- v4.0.22 proof upload RLS app support
- v4.0.21 profile photo save
- v4.0.20 client marketplace tracker
- v4.0.19 no-page-reload admin sync

## SQL
No new SQL is required for v4.0.28.

If proof upload still shows a Supabase row-level security error, run the included `RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql` once.

## Expected badge
**v4.0.28 UNIVERSAL MAP CARD SYSTEM**
