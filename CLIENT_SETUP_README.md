# Co Pilot Security Marketplace v4.0.29 — Single Source Badge Lock

Current build:
**v4.0.29 SINGLE SOURCE BADGE LOCK**

This is a GitHub-ready replacement package for the `security-uber` repo.

## What changed

v4.0.29 fixes the badge jumping issue where stacked older build-lock patches could briefly force the visible badge back to v4.0.25 or v4.0.27 after reload.

All badge lock routines now point to one current label:
**v4.0.29 SINGLE SOURCE BADGE LOCK**

The app still preserves:
- v4.0.28 Universal Map Card System
- v4.0.27 Live GPS roster + property visibility
- v4.0.26 global job state + route flow enforcement
- v4.0.25 Agency proof review + client report delivery
- v4.0.24 Guard job-flow icon sync
- v4.0.23 badge/cache protection
- v4.0.22 proof upload RLS app support
- v4.0.21 profile photo save
- v4.0.20 client tracker
- v4.0.19 no-page-reload admin sync

## SQL

No new SQL is required for v4.0.29.

If proof upload still shows a Supabase RLS error, run the included:
`RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`

## Expected badge

**v4.0.29 SINGLE SOURCE BADGE LOCK**
