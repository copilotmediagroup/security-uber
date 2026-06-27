-- Co Pilot Security Marketplace v4.0.4
-- MARKETPLACE ROLE CLEANUP
-- Run this after v4.0.3 SQL.
-- Purpose: remove old v3 Legacy Dispatch semantics from the marketplace database.

begin;

alter table if exists public.profiles
  add column if not exists marketplace_role text;

-- In the v4 marketplace, old v3 admin/dispatch accounts are treated as Platform Admin.
update public.profiles
set marketplace_role = 'platform_admin'
where lower(coalesce(marketplace_role, role, '')) in ('admin', 'dispatch', 'legacy_dispatch', 'legacy-dispatch');

-- Normalize the visible role where the project already supports platform_admin.
-- If a future environment has a restrictive role check, this statement should be the only one to review.
update public.profiles
set role = 'platform_admin'
where lower(coalesce(role, '')) in ('admin', 'dispatch', 'legacy_dispatch', 'legacy-dispatch')
  and lower(coalesce(marketplace_role, '')) = 'platform_admin';

-- Touch updated_at only when the column exists.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'updated_at'
  ) then
    update public.profiles
    set updated_at = now()
    where lower(coalesce(marketplace_role, '')) = 'platform_admin';
  end if;
end $$;

-- Tiny verification helper.
create or replace function public.cp_v404_marketplace_role_cleanup_check()
returns table (
  email text,
  role text,
  marketplace_role text,
  normalized_marketplace_role text
)
language sql
security definer
set search_path = public
as $$
  select
    p.email,
    p.role,
    p.marketplace_role,
    case
      when lower(coalesce(p.marketplace_role, p.role, '')) in ('admin','dispatch','legacy_dispatch','legacy-dispatch') then 'platform_admin'
      else lower(coalesce(p.marketplace_role, p.role, ''))
    end as normalized_marketplace_role
  from public.profiles p
  order by p.created_at desc nulls last, p.email;
$$;

grant execute on function public.cp_v404_marketplace_role_cleanup_check() to authenticated;

commit;
