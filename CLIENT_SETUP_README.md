# Co Pilot Security Marketplace v4.0.5 — Agency Guard Direct Add

This build removes public guard signup and keeps agency rosters private.

## Main rule
Guards do **not** sign up publicly and do **not** choose from a list of security companies.

Agency Admin adds guards inside the agency portal:

1. Login as Agency Admin.
2. Open **Agency Guards**.
3. Click **Add Guard**.
4. Enter guard name, email, phone, temporary password, rank/license/vehicle info.
5. Guard logs in from the normal front page using that email/password.

The password goes to Supabase Auth. It is not saved in a normal app database table.

## SQL
If you already ran v4.0.0 through v4.0.4 SQL, run only:

`RUN_AFTER_V405_AGENCY_GUARD_DIRECT_ADD.sql`

Do not rerun the old foundation SQL unless Supabase reports a missing-table error.

## Marketplace model
- Client requests job.
- Job enters open marketplace.
- Approved agency accepts job.
- Job locks to that agency.
- Agency adds/manages its own guards.
- Agency assigns one of its guards.
- Guard logs in and sees only assigned agency jobs.
