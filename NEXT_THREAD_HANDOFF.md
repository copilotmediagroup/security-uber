# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

This is separate from the old v3 single-company app called **Co Pilot Security OS**.

Current latest working package:
**v4.0.18 ADMIN LIVE ACTIVITY STATUS SYNC**

Repo:
**security-uber**

Supabase:
`https://nmfvxozbptcvyaenvkxl.supabase.co`

Publishable key is already in `config.js`.

Important business model:
- Co Pilot Security is the platform/software marketplace layer, not the licensed security provider.
- Clients request patrol jobs.
- Licensed/certified security agencies sign up and get approved.
- Approved agencies see open marketplace jobs.
- One agency accepts a job; the job locks to that agency and is removed from the open marketplace.
- The accepting agency assigns its own guard.
- Guards do not publicly sign up or choose from a list of companies. Agency Admin adds guards inside its private agency portal.
- Platform Admin sees the whole marketplace but does not dispatch for agencies.

Latest working app status:
- v4.0.17 fixed the stale `/dist/index.html` issue that made Bolt keep showing old badges.
- `server.cjs` serves root files first.
- v4.0.18 keeps that server-root entry lock and updates the badge to `v4.0.18 ADMIN LIVE ACTIVITY STATUS SYNC`.
- Platform Admin Command Center shows the marketplace-wide map, companies, guards, jobs, job ownership, and activity.
- v4.0.18 strengthens Platform Admin Marketplace Activity so it reads from `job_events`, `marketplace_jobs` timestamps, proof rows, reports, and local report publish audit rows.
- Admin activity should show: guard accepted job, en route, arrived, checking property / started patrol, proof uploaded, completed, and report published.
- Platform Command Center auto-refreshes every 6 seconds while Platform Admin dashboard is open and refreshes on browser focus/visibility.
- Agency Admin can add guards directly by email/password under the agency, accept jobs, and assign guards.
- Guard Active Job reads assigned marketplace jobs and moves through lifecycle using `marketplace_jobs.current_status` and `job_events`.

Current consolidated package:
The ZIP has fewer than 20 files and includes one all-in-one SQL file:
`RUN_IF_NEEDED_ALL_SQL_V400_TO_V417_CONSOLIDATED.sql`

No new SQL was added for v4.0.18. Do not rerun SQL unless the Supabase project is fresh or a missing table/RPC error appears.

Where to go next:
1. Upload/import the v4.0.18 ZIP into `security-uber`.
2. Verify badge says `v4.0.18 ADMIN LIVE ACTIVITY STATUS SYNC`.
3. As a guard, move an assigned marketplace job through Accept Job → En Route → Arrived → Start Patrol → Upload Proof → Complete.
4. As Platform Admin, verify Marketplace Activity updates each lifecycle step clearly.
5. Publish a report and confirm Report Published appears in Platform Admin Marketplace Activity.
6. After admin lifecycle sync is solid, build **Client Marketplace Status Tracker** showing: Open marketplace → Agency accepted → Guard assigned → Guard accepted → En route → Arrived → Checking property → Proof uploaded → Completed → Report published.
