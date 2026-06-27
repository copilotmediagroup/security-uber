# Co Pilot Security Marketplace v4.0.10 — Platform Real Map Alignment

This package fixes the Platform Admin Command Center map so it uses the same real street-map system as the other GPS views.

## What changed
- Replaced the mock diagram-style command center map.
- Added a real Leaflet/OpenStreetMap platform map.
- Platform Admin can see:
  - client property markers
  - open marketplace job markers
  - accepted/active job markers
  - online guard markers
  - assigned guard routes to jobs
- Company activity and job ownership panels remain.

## SQL
No schema change is required.

Optional cache refresh only:
`RUN_AFTER_V410_PLATFORM_REAL_MAP_ALIGNMENT.sql`

## Badge
`v4.0.10 PLATFORM REAL MAP ALIGNMENT`
