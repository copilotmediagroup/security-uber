# Co Pilot Security Marketplace v4.0.11 — Guard Marketplace Job Flow

This is a full GitHub-ready replacement package.

## SQL
If you already ran SQL through v4.0.10, run only:

`RUN_AFTER_V411_GUARD_MARKETPLACE_JOB_FLOW.sql`

## What changed
- Assigned marketplace jobs now appear in the guard Active Job page.
- Guards can accept the job, mark en route, arrived, start patrol, upload proof, and complete the job.
- The lifecycle updates `marketplace_jobs.current_status` and writes `job_events`.
- Proof can attach to `marketplace_job_id`.

Do not rerun old foundation SQL unless Supabase reports missing tables.
