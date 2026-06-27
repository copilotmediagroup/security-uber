# Co Pilot Security Marketplace v4.0.21 — Profile Photo Save Fix

This is a complete GitHub-ready replacement package for **security-uber**.

## Current build
**v4.0.21 PROFILE PHOTO SAVE FIX**

## What this fixes
Profile photos in Settings were only previewing after upload. They were not being saved to Supabase or persisted back to the user profile.

v4.0.21 fixes that flow:

1. User chooses a device image in Settings > Profile.
2. Preview appears immediately.
3. User clicks **Save Changes**.
4. File uploads to Supabase Storage bucket `profile-photos`.
5. App calls `cp_update_my_profile`.
6. `avatar_url` is saved and reflected back into the logged-in profile.
7. Matching guard/client avatar fields update in the local UI immediately.

## Supabase
Use the marketplace Supabase only:

- URL: `https://nmfvxozbptcvyaenvkxl.supabase.co`
- Publishable key is already in `config.js`

## SQL
No new SQL was added in this package. The consolidated SQL already contains the profile photo bucket, `avatar_url` columns, and `cp_update_my_profile` function.

Do **not** rerun SQL unless Supabase returns a missing bucket/table/function/RPC error.

## Preserved from earlier builds
- v4.0.19 quiet admin live sync, no page reload loop.
- v4.0.20 Client Marketplace Status Tracker.
- Root server entry lock behavior.

## Expected badge
`v4.0.21 PROFILE PHOTO SAVE FIX`
