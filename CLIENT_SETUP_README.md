# Co Pilot Security Marketplace v4.0.34

**v4.0.34 SIDEBAR NAV STACK FIX**

This build fixes the left sidebar overlap issue. The navigation now starts below the logo/name/user profile card on every portal.

## Fixed

- Platform Admin sidebar: Command Center no longer overlaps the user/profile card.
- Agency Admin sidebar: Available Jobs/Dispatch nav starts below the user card.
- Guard sidebar: Dashboard/Active Job nav starts below the user card.
- Client sidebar: Dashboard/Properties nav starts below the user card.
- Legacy Admin sidebar remains protected by the same stack rule.

## Preserved

- v4.0.33 map header text removal.
- Compact Company Activity card.
- Universal map card styling.
- Agency logo safe SQL hotfix file remains included.

## SQL

No new SQL required for the sidebar fix. Use `RUN_ONCE_V433_AGENCY_LOGO_VISIBILITY_SAFE_FIX.sql` only for the agency logo visibility issue.

Expected badge:

`v4.0.34 SIDEBAR NAV STACK FIX`
