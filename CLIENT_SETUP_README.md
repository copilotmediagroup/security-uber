# Co Pilot Security Marketplace v4.0.7 — Agency Live GPS Route Visibility

This package keeps the marketplace model clear: Co Pilot is the platform, while the licensed agency that accepts a job manages its own guards.

## What changed
- Agency Admin Live GPS now shows the agency guard roster and agency-owned jobs.
- Accepted marketplace jobs with assigned guards are treated as agency route jobs.
- The assigned guard route is drawn to the job location when GPS and property coordinates are available.
- Marketplace job service addresses can be geocoded and cached in the browser if coordinates are not already stored.
- No public guard signup or agency dropdown was reintroduced.

## SQL
No schema change is required. After upload, you may run the optional reload file:

`RUN_AFTER_V407_AGENCY_LIVE_GPS_ROUTE_VISIBILITY.sql`

## Test
1. Log in as Agency Admin.
2. Make sure an agency guard exists and has GPS online.
3. Accept a marketplace job.
4. Assign the job to the guard.
5. Open Agency Live GPS.
6. Confirm the agency guard appears and the route draws to the job location.
