# Co Pilot Security Marketplace v4.0.17 — Server Root Entry Lock + Activity Feed

This patch fixes the problem where Bolt kept showing the old v4.0.13 badge because the server was choosing stale `dist/index.html` before the updated root `index.html`.

## What changed

- `server.cjs` now always serves the root project folder.
- Root `index.html` loads `script-v417.js` with a new cache buster.
- `dist/` is still included and regenerated, but it is no longer allowed to override the root app during Bolt preview.
- The Marketplace Activity guard status feed is preserved.

## Expected badge

`v4.0.17 SERVER ROOT ENTRY LOCK + ACTIVITY FEED`

## SQL

No real schema change required. Optional only:

`RUN_AFTER_V417_SERVER_ROOT_ENTRY_LOCK_ACTIVITY_FEED.sql`
