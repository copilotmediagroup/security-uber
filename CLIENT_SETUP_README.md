# Co Pilot Security Marketplace v4.0.13 — Build Label Lock Fix

This package fixes the issue where GitHub showed v4.0.12 but Bolt still displayed the v4.0.10 badge.

## Root cause
Old module-level code inside `script.js` still reset the active build label to v4.0.10 and v4.0.11 after the file started loading. If a later lifecycle patch hit an error or initialized late, the visible badge could stay downgraded even though the repo had the new files.

## Fix
- Removed the stale v4.0.10 build-label override.
- Removed the stale v4.0.11 build-label override.
- Added a final v4.0.13 build-label lock.
- Kept the v4.0.12 Platform Lifecycle Sync Fix.

## SQL
No real schema change required.
Optional only:

`RUN_AFTER_V413_BUILD_LABEL_LOCK_FIX.sql`
