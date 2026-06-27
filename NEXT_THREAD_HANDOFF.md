# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app. Do not suggest Bolt AI prompts. The user has no Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Current repo: **security-uber**

Current latest package:
**v4.0.24 GUARD JOB FLOW ICON SYNC**

Supabase:
`https://nmfvxozbptcvyaenvkxl.supabase.co`

Publishable key is already in `config.js`.

Recent build history:
- v4.0.19 fixed Platform Admin reload loop with quiet sync.
- v4.0.20 added Client Marketplace Status Tracker.
- v4.0.21 fixed profile photo save.
- v4.0.22 added proof upload RLS app changes and `RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`.
- v4.0.23 fixed old badge lock forcing the badge back to v4.0.21.
- v4.0.24 fixes Guard Dashboard Job Flow icons not matching the real current stage.

What v4.0.24 specifically fixed:
- If guard status says **Arrived**, the **Arrived** icon/stage now lights up correctly.
- Previous steps show complete/locked after moving forward.
- Share GPS shows complete when GPS is live/shared or the workflow has passed en route.
- Guard workflow stage is saved in localStorage/sessionStorage to prevent the UI from falling backward after render.
- Marketplace statuses `en_route`, `arrived`, `in_progress`, `proof_uploaded`, and `completed` map cleanly to the visible guard flow.

Important note:
If proof upload still gives `new row violates row-level security policy`, the Supabase SQL patch still needs to be run once:
`RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`

Next likely work after testing v4.0.24:
- Verify guard flow icons now match: En Route → Arrived → Checking → Proof Uploaded → Complete.
- Verify Platform Admin and Client tracker also see each stage clearly.
- Then build agency proof review / client report delivery or pricing/platform fee logic.
