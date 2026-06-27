# Co Pilot Security Marketplace v4.0.32

## Build
**v4.0.32 COMPACT COMPANY CARD LOGO + MAP HEADER CLEANUP**

## What changed
- Removed the long text paragraph from the Platform Admin map header.
- Rebuilt **Company Activity** as a compact side-panel card.
- Kept the intended card structure:
  - logo/photo column on the left
  - company name
  - online guards
  - total guards
  - jobs in motion
  - jobs completed
- Reasserted one universal image/detail map card system across Admin, Agency, Guard, and Client maps.
- Added optional SQL support so agency profile photos/logos can persist to the agency record and show to Platform Admin.

## Supabase
Use the existing marketplace Supabase project.

Do **not** rerun the full consolidated SQL.

Only run this new one-time patch if the agency/company logo still does not appear in Platform Admin Company Activity:

`RUN_ONCE_V432_AGENCY_LOGO_VISIBILITY_FIX.sql`

After running the SQL patch, have the Agency Admin save the profile/company photo once more if the old upload does not immediately backfill.

## Expected badge
`v4.0.32 COMPACT COMPANY CARD LOGO + MAP HEADER CLEANUP`
