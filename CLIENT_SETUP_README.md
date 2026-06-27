# Co Pilot Security Marketplace v4.0.31 COMPACT COMPANY ACTIVITY + UNIVERSAL MAP CARD FIX

This is the latest GitHub-ready replacement package for the **security-uber** marketplace app.

## Build
**v4.0.31 COMPACT COMPANY ACTIVITY + UNIVERSAL MAP CARD FIX**

## What changed
- Company Activity now uses the approved professional card layout:
  - large company logo/image on the left
  - company name on the right
  - online guards
  - total guards
  - jobs in motion
  - jobs completed
- Map cards are now forced into one universal card system across:
  - Platform Admin maps
  - Agency Admin maps
  - Guard maps
  - Client maps
- Platform Admin Leaflet markers now open image/detail-rich cards instead of text-only tooltips.
- Guard cards show company name, guard name, guard image when available, and current address.
- Client/property cards show client name, property name, property image when available, and address.

## Supabase
Use the marketplace Supabase only:
`https://nmfvxozbptcvyaenvkxl.supabase.co`

The publishable key is already in `config.js`.

## SQL
No new SQL is required for v4.0.31.

The included proof-upload SQL file should only be run if proof upload still shows a Supabase RLS policy error.

## Expected badge
**v4.0.31 COMPACT COMPANY ACTIVITY + UNIVERSAL MAP CARD FIX**


## v4.0.31 Update
- Company Activity card is now compact for the side panel, about a small card height instead of a large block.
- Left logo column remains, but resized to fit the rail.
- Right-side stats show company name, online guards, total guards, jobs in motion, and jobs completed.
- Universal image/detail map cards were reapplied globally for Platform Admin, Agency Admin, Guard, and Client maps.
- No SQL required.
