# Co Pilot Security Marketplace v4.0.38 STARTUP RECOVERY + PRIORITY CARD STABILITY

## Current build
**v4.0.38 STARTUP RECOVERY + PRIORITY CARD STABILITY

This package adds **Priority Response** as a premium marketplace request type. It is not branded as a 911/emergency replacement.

## What changed
- Client Patrol Requests now includes **Priority Response**.
- Priority Response shows a required safety acknowledgement: if anyone is in immediate danger, call 911.
- The request submits through the existing `marketplace_jobs` foundation using urgent priority and on-demand flow.
- Agency Job Board pins Priority Response jobs above standard jobs and shows premium payout language.
- Platform Admin sees Priority Response live alert counts.
- Platform map uses a pulsing Priority Response marker.
- Guard Active Job shows a Priority Response assignment badge when assigned.

## SQL
No new SQL is required for v4.0.38 STARTUP RECOVERY + PRIORITY CARD STABILITY

Priority Response uses existing fields:
- `marketplace_jobs.priority`
- `marketplace_jobs.patrol_type`
- `marketplace_jobs.request_notes`

Keep the previous SQL files only for fresh projects or previous optional fixes.

## Expected badge
`v4.0.38 STARTUP RECOVERY + PRIORITY CARD STABILITY


## v4.0.38 STARTUP RECOVERY + PRIORITY CARD STABILITY
Priority Response cards were tightened and all pricing/payout language was removed until pricing, platform fees, and agency payouts are finalized. No new SQL required.


## v4.0.38 update
v4.0.38 STARTUP RECOVERY + PRIORITY CARD STABILITY

This emergency build removes the aggressive v4.0.37 DOM watcher that could leave Bolt stuck on Preparing app, adds startup recovery, keeps Priority Response no-pricing cleanup, and does not require new SQL.
