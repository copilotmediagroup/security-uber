# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

This is separate from the old v3 single-company app called **Co Pilot Security OS**.

Current latest working package:
**v4.0.20 CLIENT MARKETPLACE STATUS TRACKER**

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
- v4.0.17 fixed stale `/dist/index.html` badge issues by serving root files first.
- v4.0.18 added admin live activity sync but refreshed too aggressively.
- v4.0.19 fixed that by removing full-page admin refresh and keeping quiet admin activity/status sync.
- v4.0.20 adds Client Marketplace Status Tracker while preserving the v4.0.19 no-page-reload fix.

v4.0.20 Client Tracker:
Client Dashboard and Patrol Requests now show a marketplace timeline:
Open Marketplace → Agency Accepted → Guard Assigned → Guard Accepted → En Route → Arrived → Checking Property → Proof Uploaded → Completed → Report Published.

The tracker reads:
- `marketplace_jobs.current_status`
- `marketplace_jobs` lifecycle timestamps
- `job_events`
- proof upload rows
- report publish rows

No new SQL is required.
Do not rerun SQL unless the Supabase project is fresh or a missing table/RPC/function error appears.

Next direction:
1. Upload/test v4.0.20.
2. Confirm the badge reads **v4.0.20 CLIENT MARKETPLACE STATUS TRACKER**.
3. Client creates job and sees Open Marketplace.
4. Agency accepts and client tracker moves to Agency Accepted.
5. Agency assigns guard and tracker moves to Guard Assigned.
6. Guard lifecycle should move tracker through Guard Accepted, En Route, Arrived, Checking Property, Proof Uploaded, Completed.
7. When report publishes, tracker should show Report Published.

After tracker is solid, next build should likely be:
**v4.0.21 MARKETPLACE PRICING + PLATFORM FEE DISPLAY**

That build should show client price, agency payout, and Co Pilot platform fee without yet adding real payment processing.
