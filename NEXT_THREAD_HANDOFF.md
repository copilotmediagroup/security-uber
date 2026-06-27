# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

We are building **Co Pilot Security Marketplace**, the Uber-style marketplace version of the security patrol app. Do not suggest Bolt AI prompts because the user does not have Bolt tokens. All future changes must be complete GitHub-ready ZIP replacement packages.

Current latest package:
**v4.0.28 UNIVERSAL MAP CARD SYSTEM**

Repo:
**security-uber**

Supabase:
`https://nmfvxozbptcvyaenvkxl.supabase.co`

Publishable key is already in `config.js`.

## Business model
Co Pilot Security is the platform/software marketplace layer, not the licensed security provider. Clients request patrol jobs. Approved licensed/certified agencies accept jobs. One agency locks the job, assigns its own guard, and manages proof/report delivery. Platform Admin sees everything but does not dispatch for agencies.

## Latest v4.0.28 fix
The user said the cards used on the Agency Admin map are the cards that need to be used universally, globally on every map.

This build makes the Agency Admin compact professional map card the master card system across:
- Platform Admin maps
- Agency Admin maps
- Guard Route/GPS maps
- Guard Active Job mini maps
- Client maps
- Client property maps

Universal card rules:
- Guard card shows company name, guard name, and guard current address.
- Client/property card shows client name, property name, and property address.
- Cards are compact and professional, with one shared style/class system.

## Preserved important fixes
- v4.0.27: Agency Live GPS shows all agency guards and Platform Admin sees all guards/properties.
- v4.0.26: Routes only show during active movement, not after arrived/checking/proof/completed/report published.
- v4.0.25: Agency proof review + client report delivery.
- v4.0.24: Guard job-flow icon sync.
- v4.0.23: Badge lock.
- v4.0.22: Proof upload RLS app support.
- v4.0.21: Profile photo save.
- v4.0.20: Client Marketplace Status Tracker.
- v4.0.19: Quiet admin sync/no page reload.

## SQL
No new SQL is required for v4.0.28.
Do not rerun SQL unless Supabase reports a missing table/RPC/storage policy.

## Next likely direction
Test every map card:
- Platform Admin Live GPS / Command Center
- Agency Admin Live GPS
- Guard Route/GPS
- Guard Active Job map
- Client tracker/property map

After this, the next build should move into marketplace pricing, platform fee display, agency payout/earnings, or any remaining map/card bugs found during testing.
