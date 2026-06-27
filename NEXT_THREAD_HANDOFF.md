# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package:
v4.0.6 AGENCY ASSIGNMENT UI FIX

Important instruction:
The user is building through GitHub ZIP uploads into Bolt. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Context:
This is the v4 Uber-style marketplace project, separate from the old v3 single-company security app. Clients request jobs, approved licensed/certified agencies accept jobs, and the accepted agency assigns its own guards. Co Pilot Security is the platform/software layer, not the licensed security provider.

Current fix completed:
- Agency Job Management no longer has two assignment paths.
- The table row action now only opens/manages the job detail.
- The only Assign Guard action lives in the right-side Agency Job Detail panel.
- Fixed the guard dropdown markup so the selected guard is actually captured.
- Added select change handling for guard assignment.
- No SQL schema change was required.

Current badge:
v4.0.6 AGENCY ASSIGNMENT UI FIX

Testing path:
1. Agency Admin logs in.
2. Agency accepts a marketplace job from Available Jobs.
3. Agency opens Agency Job Management.
4. Click Manage on a job.
5. Select a guard in the right-side panel.
6. Click Assign Guard.
7. Job should move to Assigned and show guard name.

Next recommended build:
v4.0.7 GUARD ASSIGNED JOB VISIBILITY
- Guard logs in and sees only jobs assigned to that guard.
- Guard can accept/start/complete assigned marketplace job.
- Agency Admin sees guard status move through lifecycle.
