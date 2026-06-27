# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package:
v4.0.3 AGENCY DISPATCH + CLIENT LOCATION FIX

Important instruction:
The user is building through GitHub ZIP uploads into Bolt. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Context:
This is the separate v4 Uber-style marketplace version. It is not the old v3 single-company app. Clients request patrol jobs. Approved/licensed agencies accept jobs. Agencies dispatch their own guards.

New Supabase:
https://nmfvxozbptcvyaenvkxl.supabase.co
Publishable key is already in config.js.

Current SQL order for fresh Supabase:
1. RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql
2. RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql
3. RUN_AFTER_V401_AGENCY_JOB_BOARD.sql
4. RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql
5. RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql

If v4.0.0-v4.0.2 SQL already ran, only run:
RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql

What v4.0.3 completed:
- Fixed missing client location capture. Client signup now requires property/business name, address, city, state, ZIP.
- Client Approval Center now shows location data.
- Approving a client creates/updates the active client and a primary property record.
- Added Agency Dispatch board for accepted marketplace jobs.
- Agency Admin can assign an agency guard to an accepted job.
- Assignment updates marketplace_jobs.assigned_guard_id and current_status = guard_assigned.
- Marketplace job detail shows assigned guard.

Current build direction:
Next build should continue agency/guard workflow, not payments yet.

Recommended next builds:

v4.0.4 GUARD MARKETPLACE JOB FLOW
- Assigned guard sees assigned marketplace job clearly.
- Guard can accept assignment.
- Guard can start job / arrive on site / upload proof / complete job.
- Status must update marketplace_jobs as the source of truth.

v4.0.5 CLIENT MARKETPLACE STATUS TRACKER
- Client sees open marketplace, agency accepted, guard assigned, guard accepted, in progress, completed, report published.

v4.0.6 SERVICE AREA MATCHING
- Jobs only show to agencies serving the property city/state/radius.
