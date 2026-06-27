-- Co Pilot Security Marketplace v4.0.5
-- AGENCY GUARD DIRECT ADD
-- Run after v4.0.4. This does not add public guard signup. It lets an approved agency
-- link a Supabase Auth guard login to its private agency roster.

alter table public.profiles add column if not exists agency_id uuid;
alter table public.profiles add column if not exists marketplace_role text;
alter table public.guards add column if not exists agency_id uuid;
alter table public.guards add column if not exists license_state text default '';
alter table public.guards add column if not exists license_number text default '';
alter table public.guards add column if not exists rank text default 'Guard';
alter table public.guards add column if not exists notes text default '';

create index if not exists guards_agency_email_idx on public.guards(agency_id, lower(email));
create index if not exists profiles_agency_role_idx on public.profiles(agency_id, marketplace_role, role);

create or replace function public.cp_agency_create_guard_account(
  p_auth_user_id uuid default null,
  p_name text default '',
  p_email text default '',
  p_phone text default '',
  p_rank text default 'Guard',
  p_license_number text default '',
  p_license_state text default 'FL',
  p_vehicle text default '',
  p_license_plate text default '',
  p_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_agency_id uuid := public.cp_current_agency_id();
  v_admin public.profiles%rowtype := public.cp_current_profile();
  v_email text := lower(trim(coalesce(p_email, '')));
  v_name text := trim(coalesce(p_name, ''));
  v_guard public.guards%rowtype;
  v_profile public.profiles%rowtype;
  v_existing public.guards%rowtype;
begin
  if not public.cp_is_agency_admin() then
    raise exception 'Only Agency Admin can add guards.';
  end if;

  if v_agency_id is null then
    raise exception 'Agency account is not linked to an approved agency.';
  end if;

  if length(v_email) < 5 then raise exception 'Guard email is required.'; end if;
  if length(v_name) < 2 then raise exception 'Guard name is required.'; end if;

  select * into v_existing from public.guards where lower(coalesce(email,'')) = v_email limit 1;
  if found and v_existing.agency_id is not null and v_existing.agency_id <> v_agency_id then
    raise exception 'This guard email is already linked to another agency.';
  end if;

  insert into public.guards (
    auth_user_id, email, name, phone, vehicle, license_plate, work_card_number,
    status, availability_status, is_available, agency_id, license_state, license_number,
    rank, notes, created_at, updated_at
  ) values (
    p_auth_user_id, v_email, v_name, coalesce(trim(p_phone), ''), coalesce(trim(p_vehicle), ''), coalesce(trim(p_license_plate), ''), coalesce(trim(p_license_number), ''),
    'active', 'offline', false, v_agency_id, upper(coalesce(nullif(trim(p_license_state), ''), 'FL')), coalesce(trim(p_license_number), ''),
    coalesce(nullif(trim(p_rank), ''), 'Guard'), coalesce(trim(p_notes), ''), now(), now()
  )
  on conflict (email) do update set
    auth_user_id = coalesce(excluded.auth_user_id, public.guards.auth_user_id),
    name = excluded.name,
    phone = excluded.phone,
    vehicle = excluded.vehicle,
    license_plate = excluded.license_plate,
    work_card_number = excluded.work_card_number,
    status = 'active',
    agency_id = v_agency_id,
    license_state = excluded.license_state,
    license_number = excluded.license_number,
    rank = excluded.rank,
    notes = excluded.notes,
    updated_at = now()
  returning * into v_guard;

  insert into public.profiles (
    auth_user_id, email, role, marketplace_role, display_name, phone, status, agency_id, guard_id, created_at, updated_at
  ) values (
    p_auth_user_id, v_email, 'guard', 'guard', v_name, coalesce(trim(p_phone), ''), 'active', v_agency_id, v_guard.id, now(), now()
  )
  on conflict (email) do update set
    auth_user_id = coalesce(excluded.auth_user_id, public.profiles.auth_user_id),
    role = 'guard',
    marketplace_role = 'guard',
    display_name = excluded.display_name,
    phone = excluded.phone,
    status = 'active',
    agency_id = v_agency_id,
    guard_id = v_guard.id,
    updated_at = now()
  returning * into v_profile;

  update public.guards
  set auth_user_id = coalesce(v_guard.auth_user_id, v_profile.auth_user_id), updated_at = now()
  where id = v_guard.id
  returning * into v_guard;

  insert into public.agency_members (agency_id, profile_id, guard_id, member_role, status, invited_by, joined_at, created_at, updated_at)
  values (v_agency_id, v_profile.id, v_guard.id, 'guard', 'active', v_admin.id, now(), now(), now())
  on conflict (agency_id, profile_id) do update set
    guard_id = excluded.guard_id,
    member_role = 'guard',
    status = 'active',
    updated_at = now();

  return jsonb_build_object('ok', true, 'guard', row_to_json(v_guard), 'profile', row_to_json(v_profile), 'agency_id', v_agency_id);
end;
$$;

grant execute on function public.cp_agency_create_guard_account(uuid, text, text, text, text, text, text, text, text, text) to authenticated;

create or replace function public.cp_agency_set_guard_status(p_guard_id uuid, p_status text default 'inactive')
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_agency_id uuid := public.cp_current_agency_id();
  v_status text := lower(coalesce(nullif(trim(p_status), ''), 'inactive'));
  v_guard public.guards%rowtype;
begin
  if not public.cp_is_agency_admin() then
    raise exception 'Only Agency Admin can update guards.';
  end if;
  if v_status not in ('active','inactive','suspended','disabled') then
    raise exception 'Invalid guard status.';
  end if;

  update public.guards
  set status = v_status, is_available = case when v_status = 'active' then is_available else false end, updated_at = now()
  where id = p_guard_id and agency_id = v_agency_id
  returning * into v_guard;

  if not found then raise exception 'Guard is not part of your agency.'; end if;

  update public.profiles
  set status = case when v_status = 'active' then 'active' else v_status end, updated_at = now()
  where guard_id = v_guard.id or lower(coalesce(email,'')) = lower(coalesce(v_guard.email,''));

  update public.agency_members
  set status = case when v_status = 'active' then 'active' else v_status end, updated_at = now()
  where agency_id = v_agency_id and guard_id = v_guard.id;

  return jsonb_build_object('ok', true, 'guard', row_to_json(v_guard));
end;
$$;

grant execute on function public.cp_agency_set_guard_status(uuid, text) to authenticated;

-- Normalize any guard profile that already belongs to an agency by email.
update public.profiles p
set marketplace_role = 'guard', role = 'guard', agency_id = coalesce(p.agency_id, g.agency_id), guard_id = coalesce(p.guard_id, g.id), updated_at = now()
from public.guards g
where lower(coalesce(p.email,'')) = lower(coalesce(g.email,''))
  and g.agency_id is not null
  and coalesce(p.marketplace_role, p.role) = 'guard';
