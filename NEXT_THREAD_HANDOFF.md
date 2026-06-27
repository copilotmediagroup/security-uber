# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

This is separate from the old v3 single-company app called **Co Pilot Security OS**.

Current latest working package:
**v4.0.26 GLOBAL JOB STATE + MAP FLOW ENFORCEMENT**

Repo:
**security-uber**

Supabase:
`https://nmfvxozbptcvyaenvkxl.supabase.co`

Publishable key is already in `config.js`.

Important marketplace model:
- Co Pilot Security is the platform/software marketplace layer, not the licensed security provider.
- Clients request patrol jobs.
- Approved licensed/certified agencies accept marketplace jobs.
- The accepting agency assigns its own guard.
- Guard works the lifecycle.
- Agency Admin reviews proof and publishes the client-facing report.
- Platform Admin audits the marketplace, but does not dispatch or publish reports for agencies.

Latest build status:
- v4.0.25 adds Agency Proof Review + Client Report Delivery.
- v4.0.24 guard job-flow icon sync is preserved.
- v4.0.23 badge lock is preserved.
- v4.0.22 proof upload RLS app changes and SQL patch file are preserved.
- v4.0.21 profile photo save is preserved.
- v4.0.20 client marketplace tracker is preserved.
- v4.0.19 quiet admin live sync/no-page-reload is preserved.

Testing order:
1. Confirm badge reads `v4.0.26 GLOBAL JOB STATE + MAP FLOW ENFORCEMENT`.
2. Guard completes job and uploads proof.
3. Agency Admin opens Proof Review and approves/includes proof.
4. Agency Admin opens Report Builder and publishes report.
5. Client opens Reports/status tracker and sees Report Published.
6. Platform Admin should be able to audit activity but should not look like the dispatcher/report publisher.

Next likely build after this:
**v4.0.26 MARKETPLACE PRICING + PLATFORM FEE DISPLAY**

That should add client price, agency payout, Co Pilot platform fee, and job economics before agency earnings/payment flows.


## v4.0.26 GLOBAL JOB STATE + MAP FLOW ENFORCEMENT
- All live maps obey the same marketplace job lifecycle.
- Route lines only show while a guard is actively moving to the property.
- Arrived, checking property, proof uploaded, completed, and report published remove the guard-to-property route line.
- Guard map cards are compact: company name, guard name, current address.
- Client/property cards are compact: client name, property name, address.
- No new SQL required.
