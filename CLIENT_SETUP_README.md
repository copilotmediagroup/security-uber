# Co Pilot Security Marketplace v4.0.30 COMPANY ACTIVITY + UNIVERSAL MAP CARD DATA FIX

This is the latest GitHub-ready replacement package for the **security-uber** marketplace app.

## Build
**v4.0.30 COMPANY ACTIVITY + UNIVERSAL MAP CARD DATA FIX**

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
No new SQL is required for v4.0.30.

The included proof-upload SQL file should only be run if proof upload still shows a Supabase RLS policy error.

## Expected badge
**v4.0.30 COMPANY ACTIVITY + UNIVERSAL MAP CARD DATA FIX**
