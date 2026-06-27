# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Current repo: **security-uber**

Current latest package: **v4.0.22 PROOF UPLOAD RLS FIX**

Supabase: `https://nmfvxozbptcvyaenvkxl.supabase.co`

Publishable key is already in `config.js`.

Important business model:
- Co Pilot Security is the platform/software marketplace layer, not the licensed security provider.
- Clients request patrol jobs.
- Approved licensed/certified agencies accept open marketplace jobs.
- The accepting agency assigns its own guard.
- Guards are private to agencies; no public guard signup.
- Platform Admin sees the whole marketplace but does not dispatch for agencies.

Latest build history:
- v4.0.17 fixed stale dist/index.html / old badge issue.
- v4.0.18 improved Platform Admin lifecycle activity sync but refreshed too aggressively.
- v4.0.19 replaced heavy admin refresh with quiet sync/no page reload.
- v4.0.20 added Client Marketplace Status Tracker.
- v4.0.21 fixed profile photo upload/save.
- v4.0.22 fixes guard marketplace proof upload blocked by Supabase Storage RLS.

Current v4.0.22 issue solved:
The proof upload modal showed `new row violates row-level security policy`. The cause was storage.objects insert policy only allowing `patrol_request_id/...` object paths while marketplace jobs upload proof under `marketplace_job_id/...`.

Existing Supabase projects showing that error must run:
`RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`

Do not rerun all SQL unless the project is fresh or missing tables/RPCs. For fresh projects, use:
`RUN_IF_NEEDED_ALL_SQL_V400_TO_V422_CONSOLIDATED.sql`

Expected badge:
`v4.0.22 PROOF UPLOAD RLS FIX`

Next direction after testing proof upload:
1. Confirm guard proof upload saves successfully.
2. Confirm Platform Admin Activity shows Proof Uploaded.
3. Confirm Agency Proof Review sees the uploaded proof.
4. Confirm Client Status Tracker moves to Proof Uploaded.
5. Next feature build can be Marketplace Pricing + Platform Fee Display.
