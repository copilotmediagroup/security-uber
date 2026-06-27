-- Co Pilot Security Marketplace v4.0.33
-- RUN ONCE ONLY IF agency uploaded logo/image still does not appear in Platform Admin Company Activity.
-- This safe version creates missing profile/avatar columns before backfilling agency logo fields.

alter table public.agencies
add column if not exists logo_url text;

alter table public.agencies
add column if not exists brand_logo_url text;

alter table public.agencies
add column if not exists logo_public_url text;

alter table public.profiles
add column if not exists avatar_url text;

alter table public.profiles
add column if not exists profile_avatar_url text;

alter table public.profiles
add column if not exists photo_url text;

alter table public.profiles
add column if not exists profile_photo_url text;

create or replace function public.cp_update_my_agency_logo(p_logo_url text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
  v_agency_id uuid;
begin
  select am.agency_id into v_agency_id
  from public.agency_members am
  where am.profile_id = v_profile_id
    and coalesce(am.status,'active') in ('active','pending')
  order by am.created_at desc nulls last
  limit 1;

  if v_agency_id is null then
    return jsonb_build_object('ok', false, 'reason', 'no agency membership found');
  end if;

  update public.agencies
  set logo_url = p_logo_url,
      brand_logo_url = coalesce(nullif(brand_logo_url,''), p_logo_url),
      logo_public_url = coalesce(nullif(logo_public_url,''), p_logo_url),
      updated_at = now()
  where id = v_agency_id;

  return jsonb_build_object('ok', true, 'agency_id', v_agency_id, 'logo_url', p_logo_url);
end;
$$;

grant execute on function public.cp_update_my_agency_logo(text) to authenticated;

update public.agencies a
set
  logo_url = coalesce(
    nullif(a.logo_url, ''),
    nullif(a.brand_logo_url, ''),
    nullif(a.logo_public_url, ''),
    nullif(p.avatar_url, ''),
    nullif(p.profile_avatar_url, ''),
    nullif(p.photo_url, ''),
    nullif(p.profile_photo_url, ''),
    a.logo_url
  ),
  brand_logo_url = coalesce(
    nullif(a.brand_logo_url, ''),
    nullif(a.logo_url, ''),
    nullif(a.logo_public_url, ''),
    nullif(p.avatar_url, ''),
    nullif(p.profile_avatar_url, ''),
    nullif(p.photo_url, ''),
    nullif(p.profile_photo_url, ''),
    a.brand_logo_url
  ),
  logo_public_url = coalesce(
    nullif(a.logo_public_url, ''),
    nullif(a.logo_url, ''),
    nullif(a.brand_logo_url, ''),
    nullif(p.avatar_url, ''),
    nullif(p.profile_avatar_url, ''),
    nullif(p.photo_url, ''),
    nullif(p.profile_photo_url, ''),
    a.logo_public_url
  ),
  updated_at = now()
from public.agency_members am
join public.profiles p on p.id = am.profile_id
where am.agency_id = a.id
  and coalesce(am.status,'active') in ('active','pending')
  and coalesce(
    nullif(p.avatar_url, ''),
    nullif(p.profile_avatar_url, ''),
    nullif(p.photo_url, ''),
    nullif(p.profile_photo_url, ''),
    ''
  ) <> '';
