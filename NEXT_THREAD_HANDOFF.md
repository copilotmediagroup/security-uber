# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package: **v4.0.12 PLATFORM LIFECYCLE SYNC FIX**

Important: This remains the separate Uber-style security marketplace project, not the old v3 single-company app. Do not suggest Bolt AI prompts. Future changes must be complete GitHub-ready ZIP replacement packages.

Current Supabase: `https://nmfvxozbptcvyaenvkxl.supabase.co`

What v4.0.12 fixed:
- Platform Command Center now syncs with the guard marketplace lifecycle from v4.0.11.
- Platform Admin reads `marketplace_jobs.current_status`, `job_events`, and proof records together.
- Added auto-refresh while Platform Command Center is open.
- Job Ownership now shows guard accepted, en route, arrived, in progress, proof uploaded, completed, and report published statuses.
- Marketplace Activity feed shows latest guard lifecycle movement.
- Company Activity panel shows in-motion/completed counts by agency.

SQL after v4.0.11:
- Run only `RUN_AFTER_V412_PLATFORM_LIFECYCLE_SYNC_FIX.sql`.
- It is a cache-refresh/no-schema patch.

Next recommended build: **v4.0.13 CLIENT MARKETPLACE STATUS TRACKER** so clients can see the same lifecycle from their dashboard.
