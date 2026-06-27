# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package: v4.0.11 GUARD MARKETPLACE JOB FLOW

Important instruction: No Bolt AI prompts. Build complete GitHub-ready ZIP replacement packages only.

Current marketplace model:
Client creates job → job opens to approved agencies → agency accepts → agency assigns its guard → guard works lifecycle → proof/report ownership stays tied to marketplace_jobs.

What v4.0.11 added:
- Guard Active Job reads assigned `marketplace_jobs` first.
- Guard can Accept Job, Mark En Route, Mark Arrived, Start Patrol, Upload Proof, and Complete Job.
- Guard steps update `marketplace_jobs.current_status`.
- Guard steps write `job_events`.
- Proof upload can attach to `marketplace_job_id`.
- Completed marketplace jobs show in guard Completed view.

SQL to run after v4.0.10:
`RUN_AFTER_V411_GUARD_MARKETPLACE_JOB_FLOW.sql`

Recommended next build:
v4.0.12 CLIENT MARKETPLACE STATUS TRACKER — client sees open marketplace, agency accepted, guard assigned, guard accepted, en route, arrived, in progress, proof uploaded, completed, report published.
