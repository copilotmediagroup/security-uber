# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package:
v4.0.8 AGENCY LIVE GPS BOOT FIX

Important instruction:
Do not suggest Bolt AI prompts. The user has no Bolt tokens. All changes must be complete GitHub-ready ZIP replacement packages.

Current project:
Co Pilot Security Marketplace / Security Uber. Separate from old v3 single-company app.

Marketplace model:
Client requests a job → open marketplace → approved agency accepts → job locks to that agency → agency assigns its own guard → agency monitors guard route/GPS → report/proof returns through platform.

What v4.0.8 fixed:
- v4.0.7 froze on Preparing app.
- The cause was a self-recursive Live GPS route prep override created by JavaScript hoisting.
- Also disabled self-recursive property coordinate fallback.
- Kept Agency Live GPS route visibility.
- Added boot timeout/failsafe so app returns to login instead of hanging forever.

SQL:
No real schema change. Optional file included:
RUN_AFTER_V408_AGENCY_LIVE_GPS_BOOT_FIX.sql

Next likely work:
- Test Agency Admin Live GPS with assigned guard online.
- Confirm guard route to job appears.
- Then tighten Guard active job workflow for marketplace_jobs statuses.
