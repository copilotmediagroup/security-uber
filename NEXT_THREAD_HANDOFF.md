# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package:
v4.0.2 CLIENT APPROVAL CENTER

Important instruction:
The user is building through GitHub ZIP uploads into Bolt. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Context:
This is the new standalone Uber-style marketplace version, not the old v3 single-company Co Pilot Security OS. Clients request patrols. Licensed/certified agencies apply, get approved, accept jobs, then dispatch their own guards. Co Pilot Security remains the platform/software marketplace layer, not the licensed security provider.

New Supabase:
https://nmfvxozbptcvyaenvkxl.supabase.co
Publishable key is already in config.js.

SQL required:
For a fresh Supabase, run:
1. RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql
2. RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql
3. RUN_AFTER_V401_AGENCY_JOB_BOARD.sql
4. RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql

If v4.0.0 and v4.0.1 SQL are already installed, only run:
RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql

What v4.0.2 completed:
- Updated app version/badge/config to v4.0.2 CLIENT APPROVAL CENTER.
- Added Platform Admin sidebar tab: Client Approvals.
- Added Client Approval Center with Pending, Approved, Rejected, and All tabs.
- Added client application detail rail with contact info and notes.
- Added Accept Client and Reject Client actions.
- Added SQL patch replacing client approval/rejection RPCs so Platform Admin can approve/reject clients.
- Approved clients are activated in clients and profiles with marketplace_role = client.
- Preserved v4.0.1 Agency Job Board accept/decline flow.
- Preserved v4.0.0 Data Foundation.

Current build direction:
Next build should return to agency dispatch flow after the approval blockers are resolved.

Recommended next build:

v4.0.3 AGENCY DISPATCH FLOW
- Once an agency accepts a marketplace job, it appears in that agency’s dispatch board.
- Agency can assign one of its own guards.
- Guard only sees jobs assigned by their agency.
- Platform Admin can see which agency/guard owns the job.

Do not add payments yet.
