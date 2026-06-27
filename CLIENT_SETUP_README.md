# Co Pilot Security Marketplace v4.0.35

**v4.0.35 MARKETPLACE UI CONSISTENCY + FINAL PORTAL QA LOCK**

This package is a GitHub-ready replacement build for repo `security-uber`.

## What this build does

- Locks the build badge to one canonical v4.0.35 label.
- Hardens the left sidebar stack so profile cards and first nav items do not overlap on any portal.
- Keeps the Platform Admin map-header explanatory text removed.
- Keeps Company Activity compact in the right-side rail.
- Reasserts universal map card styling and image/detail card classes after every render.
- Keeps route lines limited to active movement job states only.

## SQL

No new SQL is required for v4.0.35.

Existing optional patches remain included:

- `RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql` only if proof upload still hits Storage RLS.
- `RUN_ONCE_V433_AGENCY_LOGO_VISIBILITY_SAFE_FIX.sql` only if agency logos still do not show.

Expected badge:

`v4.0.35 MARKETPLACE UI CONSISTENCY + FINAL PORTAL QA LOCK`
