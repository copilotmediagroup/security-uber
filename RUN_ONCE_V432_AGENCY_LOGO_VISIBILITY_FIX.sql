-- Co Pilot Security Marketplace v4.0.32
-- RUN ONCE ONLY IF agency/company logos do not appear in Platform Admin Company Activity.
-- Adds a persistent agency logo field and lets Agency Admin profile-photo saves mirror into the agency record.

alter table public.agencies add column if not exists logo_url text default '';
alter table public.agencies add column if not exists company_logo_url text default '';
alter table public.agencies add column if not exists brand_logo_url text default '';

create or replace function public.cp_update_my_agency_logo(p_logo_url text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_profile public.profiles%rowtype;
  v_agency_id uuid;
  v_agency public.agencies%rowtype;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(coalesce(email,'')) = v_email
  limit 1;

  if not found then
    raise exception 'No profile found for agency logo update.';
  end if;

  v_agency_id := coalesce(
    v_profile.agency_id,
    (select am.agency_id from public.agency_members am where am.profile_id = v_profile.id and am.status in ('active','pending') order by am.created_at asc limit 1)
  );

  if v_agency_id is null then
    raise exception 'No agency found for this profile.';
  end if;

  update public.agencies
  set logo_url = coalesce(nullif(p_logo_url,''), logo_url),
      company_logo_url = coalesce(nullif(p_logo_url,''), company_logo_url),
      brand_logo_url = coalesce(nullif(p_logo_url,''), brand_logo_url),
      updated_at = now()
  where id = v_agency_id
  returning * into v_agency;

  return jsonb_build_object('ok', true, 'agency', row_to_json(v_agency));
end;
$$;

grant execute on function public.cp_update_my_agency_logo(text) to authenticated;

-- Backfill: if an agency admin already saved a profile photo before this patch,
-- copy that profile photo into the agency logo fields.
update public.agencies a
set logo_url = coalesce(nullif(a.logo_url,''), nullif(p.avatar_url,''), nullif(p.profile_avatar_url,''), nullif(p.photo_url,''), nullif(p.profile_photo_url,''), a.logo_url),
    company_logo_url = coalesce(nullif(a.company_logo_url,''), nullif(p.avatar_url,''), nullif(p.profile_avatar_url,''), nullif(p.photo_url,''), nullif(p.profile_photo_url,''), a.company_logo_url),
    brand_logo_url = coalesce(nullif(a.brand_logo_url,''), nullif(p.avatar_url,''), nullif(p.profile_avatar_url,''), nullif(p.photo_url,''), nullif(p.profile_photo_url,''), a.brand_logo_url),
    updated_at = now()
from public.agency_members am
join public.profiles p on p.id = am.profile_id
where am.agency_id = a.id
  and am.status in ('active','pending')
  and coalesce(nullif(p.avatar_url,''), nullif(p.profile_avatar_url,''), nullif(p.photo_url,''), nullif(p.profile_photo_url,''), '') <> '';
