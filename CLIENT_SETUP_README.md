# Co Pilot Security Marketplace v4.0.23 — Badge Lock + Proof RLS Preserved

This package fixes the issue where the app badge still read **v4.0.21 PROFILE PHOTO SAVE FIX** after uploading v4.0.22.

## Root cause
The v4.0.21 profile-photo patch included a repeating badge lock. Because that patch was loaded near the end of the app file, it kept forcing the visible badge back to v4.0.21 even though v4.0.22 files were present.

## Current build
**v4.0.23 BADGE LOCK + PROOF RLS PRESERVED**

## What is preserved
- v4.0.22 proof upload RLS app-side fixes
- `RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql` for Supabase Storage RLS
- v4.0.21 profile photo save fix
- v4.0.20 client marketplace status tracker
- v4.0.19 quiet admin live sync / no page reload

## SQL
If you already ran `RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`, do not run it again.

If proof upload still shows `new row violates row-level security policy`, run:

`RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`

No other SQL is required for the badge fix itself.
