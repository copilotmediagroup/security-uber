# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package:
v4.0.1 AGENCY JOB BOARD

Important instruction:
The user is building through GitHub ZIP uploads into Bolt. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Project separation:
This is the new standalone v4 marketplace / Uber-style security platform. Keep it separate from the old v3 single-company Co Pilot Security OS app.

New Supabase:
https://nmfvxozbptcvyaenvkxl.supabase.co
Publishable key is already in config.js.

SQL required:
For a fresh Supabase, run:
1. RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql
2. RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql
3. RUN_AFTER_V401_AGENCY_JOB_BOARD.sql

If v4.0.0 SQL was already run, only run:
RUN_AFTER_V401_AGENCY_JOB_BOARD.sql

What v4.0.0 completed:
- Platform Admin and Agency Admin marketplace roles.
- Agency signup and agency verification center.
- marketplace_jobs as source of truth.
- job_events audit trail.
- agencies, agency_members, agency_service_areas, marketplace_job_claims.
- Client marketplace request creation and agency job acceptance RPCs.

What v4.0.1 completed:
- Agency Job Board UI for approved agency admins.
- Tabs: Available, Accepted By Us, Declined, Locked, All.
- Job rows show job number, client, property, address/city, service type, urgency, status, and actions.
- Job detail panel shows full request context before accept/decline.
- Accept job locks marketplace_jobs.accepted_agency_id through cp_agency_accept_marketplace_job.
- Decline job records a marketplace_job_claims declined row and job_events audit record through cp_agency_decline_marketplace_job.
- Declined jobs are removed from Available for that agency.
- Platform Admin can still view all marketplace jobs.

Still intentionally NOT added:
- Payments / Stripe / subscriptions.
- Closest-agency auto-matching.
- Service-area filtering.
- Bidding.
- Agency ranking/reviews.

Recommended next build:
v4.0.2 AGENCY DISPATCH FLOW
- Once an agency accepts a marketplace job, it appears in that agency’s dispatch board.
- Agency can assign one of its own guards.
- Guard only sees jobs assigned by their agency.
- Platform Admin can see which agency/guard owns the job.
