# Co Pilot Security Marketplace v4.0.25 — Agency Proof Review + Client Report Delivery

This package adds the next marketplace handoff layer: the **accepted agency** reviews guard proof, builds/publishes the final report, and the **client** sees the delivered report/status.

## Current build
**v4.0.26 GLOBAL JOB STATE + MAP FLOW ENFORCEMENT**

## What changed
- Agency Admin Proof Review is framed as agency-owned work, not platform dispatch work.
- Agency Admin sees proof tied to its accepted/assigned marketplace jobs.
- Report Builder is framed as **Agency Report Builder**.
- Published reports include agency/guard/client/job context.
- Publish attempts the existing Supabase report RPC first so the client can receive the report from `patrol_reports`.
- If Supabase blocks or the legacy request row is missing, the app also saves a marketplace delivery copy locally so the client tracker/report screen can still reflect the handoff during Bolt testing.
- Report-published audit events use **Agency Admin** language.

## Preserved from prior builds
- v4.0.24 guard job-flow icon sync
- v4.0.23 badge lock fix
- v4.0.22 proof upload RLS app changes and SQL patch file
- v4.0.21 profile photo save fix
- v4.0.20 client marketplace status tracker
- v4.0.19 quiet admin live sync / no page reload

## SQL
No new SQL is required for v4.0.25.

If proof upload still shows `new row violates row-level security policy`, run the existing SQL patch once:

`RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`


## v4.0.26 GLOBAL JOB STATE + MAP FLOW ENFORCEMENT
- All live maps obey the same marketplace job lifecycle.
- Route lines only show while a guard is actively moving to the property.
- Arrived, checking property, proof uploaded, completed, and report published remove the guard-to-property route line.
- Guard map cards are compact: company name, guard name, current address.
- Client/property cards are compact: client name, property name, address.
- No new SQL required.
