# Co Pilot Security Marketplace v4.0.22 — Proof Upload RLS Fix

This is a complete GitHub-ready replacement package for **Co Pilot Security Marketplace**.

## Build
**v4.0.22 PROOF UPLOAD RLS FIX**

## Why this build exists
The guard proof-upload modal showed:

`new row violates row-level security policy`

The issue is Supabase Storage RLS. Earlier proof storage policy allowed object paths that started with a legacy `patrol_request_id`, but marketplace proof uploads use `marketplace_job_id/file-name`. This build adds a targeted SQL patch so assigned marketplace guards can upload proof to the `patrol-proof` bucket.

## What to upload
Upload this whole ZIP to GitHub/Bolt as the replacement package.

## SQL for existing Supabase project
Because your screenshot shows a real RLS policy block, run this file **once** in Supabase SQL Editor:

`RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`

Do **not** rerun the full consolidated SQL on an existing project unless the database is fresh or missing older tables/RPCs.

## Fresh Supabase project only
For a fresh project, use:

`RUN_IF_NEEDED_ALL_SQL_V400_TO_V422_CONSOLIDATED.sql`

## Expected badge
`v4.0.22 PROOF UPLOAD RLS FIX`

## Preserved fixes
- v4.0.19 quiet admin live sync / no page reload
- v4.0.20 Client Marketplace Status Tracker
- v4.0.21 Profile Photo Save Fix
