# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

This is separate from the old v3 single-company app called **Co Pilot Security OS**.

Current latest working package:
**v4.0.21 PROFILE PHOTO SAVE FIX**

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
- v4.0.17 fixed stale `/dist/index.html`; server serves root files first.
- v4.0.18 added stronger Platform Admin activity/status sync but caused too much page refreshing.
- v4.0.19 fixed that by using quiet admin sync with no full-page reload timer.
- v4.0.20 added Client Marketplace Status Tracker.
- v4.0.21 fixes Settings profile photo saving. Previously profile photo upload only previewed locally. Now clicking Save Changes uploads to `profile-photos`, calls `cp_update_my_profile`, and updates `avatar_url` in the profile plus matching guard/client UI records.

SQL:
The uploaded package still includes:
`RUN_IF_NEEDED_ALL_SQL_V400_TO_V417_CONSOLIDATED.sql`

Do not rerun SQL unless the Supabase project is fresh or a missing bucket/table/RPC/function error appears. The profile photo support is already inside the consolidated SQL.

Where to go next:
1. Upload v4.0.21 and confirm badge reads `v4.0.21 PROFILE PHOTO SAVE FIX`.
2. Test Settings > Profile > Upload Photo > Save Changes for Platform Admin, Agency Admin, Guard, and Client.
3. Confirm photo remains after refresh/logout/login.
4. If profile photos are solid, continue marketplace money flow: pricing, agency payout, platform fee, and client payment authorization.
