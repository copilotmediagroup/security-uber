-- Co Pilot Security Marketplace v4.0.3 — Agency Dispatch + Client Location Fix
-- Run after RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql.
-- Adds required client signup location fields and the agency dispatch assignment support used by v4.0.3.

alter table public.pending_client_signups add column if not exists property_label text default '';
alter table public.pending_client_signups add column if not exists address_line1 text default '';
alter table public.pending_client_signups add column if not exists address text default '';
alter table public.pending_client_signups add column if not exists city text default '';
alter table public.pending_client_signups add column if not exists state text default '';
alter table public.pending_client_signups add column if not exists zip_code text default '';

alter table public.clients add column if not exists address_line1 text default '';
alter table public.clients add column if not exists address text default '';
alter table public.clients add column if not exists city text default '';
alter table public.clients add column if not exists state text default '';
alter table public.clients add column if not exists zip_code text default '';

create index if not exists pending_client_signups_city_state_idx on public.pending_client_signups (lower(city), lower(state));
create index if not exists clients_city_state_idx on public.clients (lower(city), lower(state));
create index if not exists properties_city_state_idx on public.properties (lower(city), lower(state));

create or replace function public.cp_submit_client_signup(
  p_auth_user_id uuid,
  p_name text,
  p_email text,
  p_phone text default '',
  p_property_label text default '',
  p_address_line1 text default '',
  p_city text default '',
  p_state text default '',
  p_zip_code text default '',
  p_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text := lower(trim(p_email));
  v_id uuid;
  v_uid uuid := coalesce(p_auth_user_id, public.cp_auth_user_id_for_email(v_email));
  v_full_address text;
begin
  if coalesce(trim(p_name), '') = '' then raise exception 'Client name is required.'; end if;
  if v_email = '' then raise exception 'Client email is required.'; end if;
  if coalesce(trim(p_address_line1), '') = '' then raise exception 'Client service address is required.'; end if;
  if coalesce(trim(p_city), '') = '' then raise exception 'Client service city is required.'; end if;
  if coalesce(trim(p_state), '') = '' then raise exception 'Client service state is required.'; end if;
  if coalesce(trim(p_zip_code), '') = '' then raise exception 'Client service ZIP is required.'; end if;

  v_full_address := concat_ws(', ', trim(p_address_line1), trim(p_city), upper(trim(p_state)), trim(p_zip_code));

  select id into v_id
  from public.pending_client_signups
  where lower(email) = v_email and status = 'pending'
  limit 1;

  if v_id is null then
    insert into public.pending_client_signups (
      auth_user_id, name, email, phone, property_label, address_line1, address, city, state, zip_code, notes, status, created_at, updated_at
    ) values (
      v_uid, trim(p_name), v_email, coalesce(p_phone, ''), coalesce(nullif(trim(p_property_label), ''), trim(p_name) || ' Primary Location'),
      trim(p_address_line1), v_full_address, trim(p_city), upper(trim(p_state)), trim(p_zip_code), coalesce(p_notes, ''), 'pending', now(), now()
    ) returning id into v_id;
  else
    update public.pending_client_signups set
      auth_user_id = coalesce(v_uid, auth_user_id),
      name = trim(p_name),
      phone = coalesce(p_phone, ''),
      property_label = coalesce(nullif(trim(p_property_label), ''), trim(p_name) || ' Primary Location'),
      address_line1 = trim(p_address_line1),
      address = v_full_address,
      city = trim(p_city),
      state = upper(trim(p_state)),
      zip_code = trim(p_zip_code),
      notes = coalesce(p_notes, ''),
      updated_at = now()
    where id = v_id;
  end if;

  return jsonb_build_object('ok', true, 'signup_id', v_id, 'status', 'pending');
end;
$$;

create or replace function public.cp_approve_client_signup(p_signup_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  s record;
  v_uid uuid;
  v_client public.clients%rowtype;
  v_profile_id uuid;
  v_property_id uuid;
  v_label text;
  v_line text;
  v_full text;
begin
  if not public.cp_is_platform_admin() then
    raise exception 'Only Platform Admin can approve clients.';
  end if;

  select * into s
  from public.pending_client_signups
  where id = p_signup_id
  for update;

  if not found then
    raise exception 'Client signup not found.';
  end if;

  v_uid := coalesce(s.auth_user_id, public.cp_auth_user_id_for_email(s.email));
  if v_uid is null then
    raise exception 'No Supabase Auth user exists for this client email.';
  end if;

  v_label := coalesce(nullif(trim(s.property_label), ''), s.name || ' Primary Location');
  v_line := coalesce(nullif(trim(s.address_line1), ''), nullif(trim(s.address), ''));
  v_full := coalesce(nullif(trim(s.address), ''), concat_ws(', ', v_line, nullif(trim(s.city), ''), nullif(trim(s.state), ''), nullif(trim(s.zip_code), '')));

  insert into public.clients (auth_user_id, email, name, phone, notes, status, address_line1, address, city, state, zip_code, created_at, updated_at)
  values (v_uid, lower(s.email), s.name, coalesce(s.phone, ''), coalesce(s.notes, ''), 'active', coalesce(v_line, ''), coalesce(v_full, ''), coalesce(s.city, ''), coalesce(s.state, ''), coalesce(s.zip_code, ''), now(), now())
  on conflict (email) do update set
    auth_user_id = excluded.auth_user_id,
    name = excluded.name,
    phone = excluded.phone,
    notes = excluded.notes,
    status = 'active',
    address_line1 = excluded.address_line1,
    address = excluded.address,
    city = excluded.city,
    state = excluded.state,
    zip_code = excluded.zip_code,
    updated_at = now()
  returning * into v_client;

  select id into v_property_id
  from public.properties
  where client_id = v_client.id
    and lower(coalesce(address_line1, address, '')) = lower(coalesce(v_line, v_full, ''))
  limit 1;

  if v_property_id is null then
    insert into public.properties (client_id, label, address, address_line1, city, state, zip_code, notes, created_at, updated_at)
    values (v_client.id, v_label, coalesce(v_full, ''), coalesce(v_line, ''), coalesce(s.city, ''), coalesce(s.state, ''), coalesce(s.zip_code, ''), coalesce(s.notes, ''), now(), now())
    returning id into v_property_id;
  else
    update public.properties set
      label = v_label,
      address = coalesce(v_full, address),
      address_line1 = coalesce(v_line, address_line1),
      city = coalesce(s.city, city),
      state = coalesce(s.state, state),
      zip_code = coalesce(s.zip_code, zip_code),
      notes = coalesce(s.notes, notes),
      updated_at = now()
    where id = v_property_id;
  end if;

  select id into v_profile_id
  from public.profiles
  where id = v_uid or auth_user_id = v_uid or lower(coalesce(email, '')) = lower(s.email)
  limit 1;

  if v_profile_id is null then
    insert into public.profiles (
      id, auth_user_id, email, role, marketplace_role, display_name, phone, status, client_id, created_at, updated_at
    ) values (
      v_uid, v_uid, lower(s.email), 'client', 'client', s.name, coalesce(s.phone, ''), 'active', v_client.id, now(), now()
    );
  else
    update public.profiles set
      auth_user_id = v_uid,
      email = lower(s.email),
      role = 'client',
      marketplace_role = 'client',
      display_name = s.name,
      phone = coalesce(s.phone, ''),
      status = 'active',
      client_id = v_client.id,
      updated_at = now()
    where id = v_profile_id;
  end if;

  update public.pending_client_signups set
    status = 'approved',
    reviewed_by = public.cp_current_uid(),
    reviewed_at = now(),
    updated_at = now()
  where id = p_signup_id;

  return jsonb_build_object('ok', true, 'client', row_to_json(v_client), 'property_id', v_property_id);
end;
$$;

-- Keep the guard assignment RPC idempotent and marketplace-source-of-truth safe.
create or replace function public.cp_agency_assign_guard_to_job(p_job_id uuid, p_guard_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_agency_id uuid := public.cp_current_agency_id();
  v_guard public.guards%rowtype;
  v_job public.marketplace_jobs%rowtype;
begin
  if not public.cp_is_agency_admin() then raise exception 'Only agency admins can assign guards.'; end if;
  if v_agency_id is null then raise exception 'Agency not found for this login.'; end if;

  select * into v_job from public.marketplace_jobs where id = p_job_id and accepted_agency_id = v_agency_id for update;
  if not found then raise exception 'Job is not accepted by your agency.'; end if;

  select * into v_guard from public.guards where id = p_guard_id and agency_id = v_agency_id limit 1;
  if not found then raise exception 'Guard is not part of your agency.'; end if;

  update public.marketplace_jobs
  set assigned_guard_id = v_guard.id,
      current_status = 'guard_assigned',
      guard_assigned_at = coalesce(guard_assigned_at, now()),
      updated_at = now()
  where id = v_job.id
  returning * into v_job;

  update public.patrol_requests
  set guard_id = v_guard.id,
      status = 'assigned',
      current_status = 'guard_assigned',
      assigned_at = coalesce(assigned_at, now()),
      updated_at = now()
  where id = v_job.patrol_request_id;

  perform public.cp_record_job_event(v_job.id, 'guard_assigned', 'Agency assigned guard', coalesce(v_guard.name, v_guard.email, 'Guard') || ' assigned to ' || v_job.job_number, jsonb_build_object('guard_id', v_guard.id, 'agency_id', v_agency_id));

  return jsonb_build_object('ok', true, 'job', row_to_json(v_job), 'guard', row_to_json(v_guard));
end;
$$;

grant execute on function public.cp_submit_client_signup(uuid, text, text, text, text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.cp_approve_client_signup(uuid) to authenticated;
grant execute on function public.cp_agency_assign_guard_to_job(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
