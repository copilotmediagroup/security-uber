# Co Pilot Security Marketplace v4.0.16 — Script Cache Killer + Activity Feed

This patch is specifically for the issue where Bolt/GitHub kept showing the old v4.0.13 badge after later uploads.

## Main fix
`index.html` now loads:

```html
<script src="script-v416.js?...">
```

instead of the previously cached `script.js`.

The normal `script.js` is still included, but the app entry file is now uniquely named so Bolt/browser cache cannot keep serving the old badge code.

## SQL
No real schema change required. Optional cache refresh only:

```sql
RUN_AFTER_V416_SCRIPT_CACHE_KILLER_ACTIVITY_FEED.sql
```
