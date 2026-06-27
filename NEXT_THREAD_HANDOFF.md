# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package:
v4.0.0 MARKETPLACE DATA FOUNDATION

Important instruction:
The user is building through GitHub ZIP uploads into Bolt. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Context:
The user is preserving the v3 single-company Co Pilot Security app separately. This v4 project is a new Uber-style marketplace version where clients request patrol jobs and verified/licensed security agencies can accept those jobs. Guards should belong to an approved agency, not operate as random independent providers.

New Supabase:
https://nmfvxozbptcvyaenvkxl.supabase.co
Publishable key is already in config.js.

SQL required:
For a fresh Supabase, run:
1. RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql
2. RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql

What v4.0.0 completed:
- Updated app version/badge/config to v4.0.0 MARKETPLACE DATA FOUNDATION.
- Added marketplace roles: platform_admin and agency_admin.
- Added agency signup public flow.
- Added Platform Admin Agency Verification Center UI.
- Added Marketplace Jobs UI.
- Added Marketplace Data Foundation dashboard.
- Added new SQL file for agencies, agency_members, agency_service_areas, marketplace_jobs, marketplace_job_claims, and job_events.
- Added indexing around agency ownership, job status, client/property/guard linkage, reports, proof, and audit events.
- Added RPCs for platform bootstrap, agency signup, agency review, marketplace request creation, agency job acceptance, agency guard assignment, event recording, and global app data loading.
- Preserved v3.0.77 Recent Reports thumbnail fix and prior v3 report/proof/dashboard sync work.

Current build direction:
This is the foundation only. Next builds should not add payments yet.

Recommended next builds:

v4.0.1 AGENCY JOB BOARD FLOW
- Make approved Agency Admin dashboard cleaner.
- Open jobs list, job detail, accept job button, accepted jobs tab.
- Lock accepted jobs to the accepted agency.

v4.0.2 AGENCY DISPATCH FLOW
- Agency assigns its own guard after accepting job.
- Guard sees assigned marketplace job.
- Platform Admin can see which agency/guard owns the job.

v4.0.3 CLIENT MARKETPLACE STATUS TRACKER
- Client sees marketplace status clearly:
  open marketplace, agency accepted, guard assigned, in progress, completed, report published.

v4.0.4 SERVICE AREA MATCHING
- Jobs only show to agencies that serve the property city/radius.

v4.0.5 MARKETPLACE REPORT OWNERSHIP
- Final reports show performing agency, guard, license info placeholder, timestamps, and proof.
