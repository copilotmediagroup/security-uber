# NEXT THREAD HANDOFF — CO PILOT SECURITY MARKETPLACE

Latest package: v4.0.16 SCRIPT CACHE KILLER + ACTIVITY FEED

Reason for build:
- User uploaded v4.0.14/v4.0.15, but visible badge kept reading v4.0.13.
- v4.0.16 changes the entry script from `script.js` to `script-v416.js` in index.html to bypass stale Bolt/browser script caching.

Preserved work:
- Platform Command Center real map.
- Guard Marketplace Job Flow.
- Platform lifecycle sync.
- Marketplace Activity guard status feed.

Expected badge:
`v4.0.16 SCRIPT CACHE KILLER + ACTIVITY FEED`

SQL:
No real schema change. Optional cache refresh only: RUN_AFTER_V416_SCRIPT_CACHE_KILLER_ACTIVITY_FEED.sql
