# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package:
v4.0.5 AGENCY GUARD DIRECT ADD

Important instruction:
The user is building through GitHub ZIP uploads into Bolt. Do not suggest Bolt AI prompts. All changes must be complete GitHub-ready ZIP replacement packages.

Project:
Co Pilot Security Marketplace / Security Uber — separate from old v3 single-company app.

Current Supabase:
https://nmfvxozbptcvyaenvkxl.supabase.co

Latest marketplace flow:
Client requests patrol job → job goes to open marketplace → approved agency accepts → job locks to agency → agency assigns its own guard → guard performs job → proof/report goes to client through platform.

What v4.0.5 completed:
- Removed public guard signup from the front page.
- No public agency/company dropdown for guards.
- Agency Admin can add guard directly inside Agency Guards.
- Add Guard form collects name, email, phone, temporary password, rank, license info, vehicle, notes.
- Frontend creates Supabase Auth user without switching the agency admin session.
- SQL RPC links guard profile, guard record, and agency_members to the agency.
- Guard uses normal front login with email/password.
- Agency Admin sees only its private guard roster.

SQL order:
If v4.0.0-v4.0.4 SQL already ran, run only:
RUN_AFTER_V405_AGENCY_GUARD_DIRECT_ADD.sql

Recommended next build:
v4.0.6 GUARD ASSIGNED JOB FLOW
- Guard dashboard should show marketplace job assigned by agency.
- Guard accepts assignment.
- Guard starts patrol.
- Guard uploads proof.
- Guard completes job.
- Job status updates only from marketplace_jobs and job_events.
