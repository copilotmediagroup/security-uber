# Co Pilot Security Marketplace v4.0.36 — Priority Response Marketplace Flow

## Current build
**v4.0.36 PRIORITY RESPONSE MARKETPLACE FLOW**

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
No new SQL is required for v4.0.36.

Priority Response uses existing fields:
- `marketplace_jobs.priority`
- `marketplace_jobs.patrol_type`
- `marketplace_jobs.request_notes`

Keep the previous SQL files only for fresh projects or previous optional fixes.

## Expected badge
`v4.0.36 PRIORITY RESPONSE MARKETPLACE FLOW`
