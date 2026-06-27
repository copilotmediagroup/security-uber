# Co Pilot Security Marketplace v4.0.33

Current build:
**v4.0.33 MAP HEADER TEXT REMOVED + AGENCY LOGO SQL HOTFIX**

This build fixes the Platform Admin map header text that was still visible beside the map.

## What changed
- Removed the text: "Platform Admin sees every mapped client property and every mapped guard record. Route lines only appear for active movement jobs."
- Removes the old ownership-overlay header copy too.
- Keeps the map title and controls only.
- Keeps the compact Company Activity card in the side panel.
- Preserves universal map cards and prior marketplace flow fixes.

## SQL
Do not rerun the full consolidated SQL.

If the uploaded agency logo still does not show, run this safe patch once:
`RUN_ONCE_V433_AGENCY_LOGO_VISIBILITY_SAFE_FIX.sql`

Badge should read:
`v4.0.33 MAP HEADER TEXT REMOVED + AGENCY LOGO SQL HOTFIX`
