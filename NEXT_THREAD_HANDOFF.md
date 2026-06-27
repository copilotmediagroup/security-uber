# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package:
v4.0.4 MARKETPLACE ROLE CLEANUP

Important instruction:
The user is building through GitHub ZIP uploads into Bolt. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Project:
Co Pilot Security Marketplace / Security Uber. This is separate from the old v3 single-company Co Pilot Security OS.

New Supabase:
https://nmfvxozbptcvyaenvkxl.supabase.co
Publishable key is already in config.js.

Current marketplace model:
- Client requests patrol job.
- Job is created as an open marketplace job.
- Approved/licensed agencies can see open jobs.
- One agency accepts job.
- Job locks to that agency and leaves the open marketplace.
- The accepting agency assigns one of its own guards.
- Co Pilot Security stays the platform/software layer, not the licensed security provider.

What v4.0.4 completed:
- Removed public Legacy Dispatch login option.
- Normalized old v3 admin/dispatch accounts as Platform Admin in the marketplace UI.
- Platform Admin is the Co Pilot marketplace owner/operator role.
- Agency Admin is the licensed security agency role.
- Renamed Agency Dispatch to Agency Job Management.
- Platform Admin no longer sees old dispatch-board/pending-dispatch nav.
- Preserved v4.0.3 client location capture and agency guard assignment.

SQL required if previous SQL through v4.0.3 already ran:
RUN_AFTER_V404_MARKETPLACE_ROLE_CLEANUP.sql

Fresh SQL order:
1. RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql
2. RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql
3. RUN_AFTER_V401_AGENCY_JOB_BOARD.sql
4. RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql
5. RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql
6. RUN_AFTER_V404_MARKETPLACE_ROLE_CLEANUP.sql

Recommended next build:
v4.0.5 GUARD AGENCY MEMBERSHIP CLEANUP
- Guards should belong to an approved agency.
- Agency Admin should invite/add/approve its own guards.
- Guard login should only show agency-assigned jobs.
- Platform Admin should not be the normal guard approver.
- Make agency_members the source of truth for guard membership.
