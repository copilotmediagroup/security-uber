# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All changes must be complete GitHub-ready ZIP replacement packages.

Current repo:
**security-uber**

Current latest package:
**v4.0.29 SINGLE SOURCE BADGE LOCK**

Supabase:
`https://nmfvxozbptcvyaenvkxl.supabase.co`

Publishable key is already in `config.js`.

## Latest v4.0.29 fix

The previous v4.0.28 package could show the correct badge on first load and then jump backward to v4.0.27 or v4.0.25 because several older stacked patch blocks still had their own repeating badge lock intervals.

v4.0.29 makes the badge single-source again:
- All older badge lock constants now point to **v4.0.29 SINGLE SOURCE BADGE LOCK**.
- `index.html` loads `script-v429.js`.
- `config.js`, `VERSION.txt`, package metadata, and page meta tags are updated.
- No app logic from v4.0.28 was removed.

## Preserved working fixes

- v4.0.28: Agency Admin compact map card style became universal across maps.
- v4.0.27: Agency Live GPS shows all agency guards and Platform Admin sees all guards/properties.
- v4.0.26: Routes only show during active movement, not after arrived/checking/proof/completed/report published.
- v4.0.25: Agency proof review + client report delivery.
- v4.0.24: Guard job-flow icon sync.
- v4.0.23: Badge/cache protection.
- v4.0.22: Proof upload RLS app support.
- v4.0.21: Profile photo save.
- v4.0.20: Client Marketplace Status Tracker.
- v4.0.19: No-page-reload admin sync.

## SQL

No new SQL is required for v4.0.29.

Only run `RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql` if proof uploads still show a Supabase RLS error.

## Expected badge

**v4.0.29 SINGLE SOURCE BADGE LOCK**
