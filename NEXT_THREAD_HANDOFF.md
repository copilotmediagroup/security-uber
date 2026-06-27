# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Current repo: **security-uber**

Current latest build:
**v4.0.41 AGENCY AVAILABILITY + PRIORITY ACCEPTANCE RULES**

This is the Uber-style marketplace version of the security patrol app, separate from the old single-company Co Pilot Security OS. Do not suggest Bolt AI prompts. Future changes should be complete GitHub-ready ZIP replacement packages.

Supabase:
`https://nmfvxozbptcvyaenvkxl.supabase.co`

Current state:
- Client can create Standard Patrol and Priority Response requests.
- Priority Response is not called Emergency in-product and includes 911 safety language.
- Priority Response pricing is intentionally hidden for now.
- Agencies see Priority Response jobs pinned/highlighted.
- v4.0.41 adds agency availability checks and immediate dispatch confirmation before an agency accepts a Priority Response.
- If accepted, the job locks to the agency and routes to Agency Job Management for guard assignment.
- Platform Admin sees oversight warnings for priority jobs accepted without guard assignment.
- Client tracker/dashboard can show waiting for agency acceptance or guard assignment.

Next likely build:
**v4.0.42 MARKETPLACE PRICING + PLATFORM FEE DISPLAY**
Only build pricing after the operational Priority Response flow is stable.
