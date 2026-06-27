# Co Pilot Security Marketplace v4.0.24 — Guard Job Flow Icon Sync

This package fixes the Guard Dashboard **Job Flow** display where the text status could say **Arrived** while the step icons still looked like they had not advanced.

## Current build
**v4.0.24 GUARD JOB FLOW ICON SYNC**

## What changed
- Guard Dashboard job-flow icons now use the same workflow stage as the Active Job buttons.
- `Arrived` now lights up immediately when the guard marks arrived.
- Earlier stages lock/show complete correctly after moving forward.
- `Share GPS` now shows complete when GPS has been shared or the guard has reached the arrived stage.
- Guard workflow stage is saved in `localStorage` and `sessionStorage`, so the UI stays in sync after render/refresh.
- Marketplace job statuses such as `en_route`, `arrived`, `in_progress`, `proof_uploaded`, and `completed` map cleanly to the guard flow.

## Preserved from prior builds
- v4.0.23 badge lock fix
- v4.0.22 proof upload RLS app changes and SQL patch file
- v4.0.21 profile photo save fix
- v4.0.20 client marketplace status tracker
- v4.0.19 quiet admin live sync / no page reload

## SQL
No new SQL is required for v4.0.24.

If proof upload still shows `new row violates row-level security policy`, run this existing SQL patch once:

`RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql`
