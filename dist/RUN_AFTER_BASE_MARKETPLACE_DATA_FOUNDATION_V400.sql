-- Co Pilot Security v4.0.0 — Marketplace Data Foundation
-- Run this AFTER the existing consolidated base schema on the NEW v4 Supabase project.
-- New Supabase project for v4 marketplace:
-- https://nmfvxozbptcvyaenvkxl.supabase.co
--
-- Purpose:
-- - Turn the app data model into a licensed-agency marketplace foundation.
-- - marketplace_jobs becomes the global source of truth.
-- - job_events becomes the audit/timeline backbone.
-- - Every client request, agency acceptance, guard assignment, proof item, report,
--   notification, and future payment should connect back to marketplace_jobs.id.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1) Global identity / ownership columns
-- -----------------------------------------------------------------------------
alter table public.profiles add column if not exists agency_id uuid;
alter table public.profiles add column if not exists marketplace_role text;
alter table public.profiles add column if not exists last_login_at timestamptz;

alter table public.guards add column if not exists agency_id uuid;
alter table public.guards add column if not exists license_state text default '';
alter table public.guards add column if not exists license_number text default '';
alter table public.guards add column if not exists guard_license_url text default '';

alter table public.patrol_requests add column if not exists marketplace_job_id uuid;
alter table public.patrol_requests add column if not exists accepted_agency_id uuid;
alter table public.patrol_requests add column if not exists agency_id uuid;
alter table public.patrol_requests add column if not exists current_status text;
alter table public.patrol_requests add column if not exists job_number text;

alter table public.patrol_proof_items add column if not exists marketplace_job_id uuid;
alter table public.patrol_reports add column if not exists marketplace_job_id uuid;
alter table public.patrol_reports add column if not exists agency_id uuid;
alter table public.patrol_reports add column if not exists client_id uuid;
alter table public.patrol_reports add column if not exists property_id uuid;
alter table public.patrol_reports add column if not exists guard_id uuid;

-- -----------------------------------------------------------------------------
-- 2) Licensed agency marketplace tables
-- -----------------------------------------------------------------------------
create table if not exists public.agencies (
  id uuid primary key default gen_random_uuid(),
  agency_name text not null default 'Security Agency',
  legal_name text default '',
  contact_name text default '',
  contact_email text default '',
  contact_phone text default '',
  license_state text default 'FL',
  license_number text default '',
  license_document_url text default '',
  insurance_document_url text default '',
  insurance_provider text default '',
  insurance_expires_at date,
  approval_status text not null default 'pending',
  verification_status text not null default 'unverified',
  rejection_reason text default '',
  suspended_reason text default '',
  primary_city text default '',
  primary_state text default 'FL',
  service_cities text default '',
  service_radius_miles numeric default 25,
  service_notes text default '',
  armed_services boolean default false,
  unarmed_services boolean default true,
  rating numeric default 0,
  completed_jobs_count integer default 0,
  platform_notes text default '',
  approved_by uuid,
  approved_at timestamptz,
  rejected_at timestamptz,
  suspended_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.agency_members (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  guard_id uuid references public.guards(id) on delete set null,
  member_role text not null default 'agency_admin',
  status text not null default 'active',
  invited_by uuid,
  joined_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(agency_id, profile_id)
);

create table if not exists public.agency_service_areas (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  city text default '',
  county text default '',
  state text default 'FL',
  center_lat double precision,
  center_lng double precision,
  radius_miles numeric default 25,
  status text default 'active',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.marketplace_jobs (
  id uuid primary key default gen_random_uuid(),
  job_number text unique not null,
  patrol_request_id uuid references public.patrol_requests(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  property_id uuid references public.properties(id) on delete set null,
  requested_by_profile_id uuid references public.profiles(id) on delete set null,
  accepted_agency_id uuid references public.agencies(id) on delete set null,
  assigned_guard_id uuid references public.guards(id) on delete set null,
  current_status text not null default 'open_marketplace',
  priority text default 'normal',
  patrol_type text default 'standard',
  proof_preference text default 'photo',
  request_notes text default '',
  schedule_type text default 'on_demand',
  scheduled_for timestamptz,
  schedule_start_date date,
  schedule_end_date date,
  preferred_time_window text default '',
  recurrence_pattern text default '',
  recurrence_days text default '',
  schedule_notes text default '',
  estimated_value numeric default 0,
  platform_fee_percent numeric default 15,
  agency_payout_amount numeric default 0,
  proof_count integer default 0,
  report_id uuid,
  requested_at timestamptz default now(),
  agency_accepted_at timestamptz,
  guard_assigned_at timestamptz,
  guard_accepted_at timestamptz,
  started_at timestamptz,
  proof_uploaded_at timestamptz,
  completed_at timestamptz,
  report_published_at timestamptz,
  client_viewed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text default '',
  dispute_status text default '',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.job_events (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.marketplace_jobs(id) on delete cascade,
  patrol_request_id uuid references public.patrol_requests(id) on delete set null,
  event_type text not null,
  event_status text default '',
  actor_profile_id uuid references public.profiles(id) on delete set null,
  actor_agency_id uuid references public.agencies(id) on delete set null,
  actor_guard_id uuid references public.guards(id) on delete set null,
  actor_role text default '',
  actor_name text default '',
  title text default '',
  details text default '',
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.marketplace_job_claims (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.marketplace_jobs(id) on delete cascade,
  agency_id uuid not null references public.agencies(id) on delete cascade,
  status text not null default 'accepted',
  response_notes text default '',
  accepted_by_profile_id uuid references public.profiles(id) on delete set null,
  accepted_at timestamptz default now(),
  created_at timestamptz default now(),
  unique(job_id, agency_id)
);

-- -----------------------------------------------------------------------------
-- 3) Indexes — this is the part that keeps dashboards globally synced and fast
-- -----------------------------------------------------------------------------
create index if not exists profiles_agency_id_idx on public.profiles(agency_id);
create index if not exists profiles_marketplace_role_idx on public.profiles(marketplace_role);
create index if not exists guards_agency_id_idx on public.guards(agency_id);
create index if not exists patrol_requests_marketplace_job_id_idx on public.patrol_requests(marketplace_job_id);
create index if not exists patrol_requests_accepted_agency_idx on public.patrol_requests(accepted_agency_id);
create index if not exists patrol_requests_current_status_idx on public.patrol_requests(current_status);
create index if not exists proof_items_marketplace_job_idx on public.patrol_proof_items(marketplace_job_id);
create index if not exists reports_marketplace_job_idx on public.patrol_reports(marketplace_job_id);
create index if not exists reports_agency_idx on public.patrol_reports(agency_id);

create index if not exists agencies_status_idx on public.agencies(approval_status, verification_status);
create index if not exists agencies_license_idx on public.agencies(license_state, license_number);
create index if not exists agencies_created_at_idx on public.agencies(created_at desc);
create index if not exists agency_members_agency_idx on public.agency_members(agency_id, status);
create index if not exists agency_members_profile_idx on public.agency_members(profile_id, status);
create index if not exists agency_service_area_agency_idx on public.agency_service_areas(agency_id, status);
create index if not exists marketplace_jobs_status_idx on public.marketplace_jobs(current_status, created_at desc);
create index if not exists marketplace_jobs_client_idx on public.marketplace_jobs(client_id, created_at desc);
create index if not exists marketplace_jobs_property_idx on public.marketplace_jobs(property_id);
create index if not exists marketplace_jobs_agency_idx on public.marketplace_jobs(accepted_agency_id, current_status, created_at desc);
create index if not exists marketplace_jobs_guard_idx on public.marketplace_jobs(assigned_guard_id, current_status, created_at desc);
create index if not exists marketplace_jobs_request_idx on public.marketplace_jobs(patrol_request_id);
create index if not exists job_events_job_idx on public.job_events(job_id, created_at desc);
create index if not exists job_events_request_idx on public.job_events(patrol_request_id, created_at desc);
create index if not exists job_events_type_idx on public.job_events(event_type, created_at desc);
create index if not exists marketplace_job_claims_job_idx on public.marketplace_job_claims(job_id);
create index if not exists marketplace_job_claims_agency_idx on public.marketplace_job_claims(agency_id, status);

-- -----------------------------------------------------------------------------
-- 4) Role helpers
-- -----------------------------------------------------------------------------
create or replace function public.cp_current_profile()
returns public.profiles
language plpgsql
security definer
set search_path = public, auth
stable
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(coalesce((auth.jwt() ->> 'email'), ''));
  v_profile public.profiles%rowtype;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(coalesce(email,'')) = v_email
  limit 1;
  return v_profile;
end;
$$;

create or replace function public.cp_current_profile_id()
returns uuid
language sql
security definer
set search_path = public, auth
stable
as $$ select (public.cp_current_profile()).id; $$;

create or replace function public.cp_current_agency_id()
returns uuid
language sql
security definer
set search_path = public, auth
stable
as $$
  select coalesce(
    (public.cp_current_profile()).agency_id,
    (select am.agency_id from public.agency_members am where am.profile_id = (public.cp_current_profile()).id and am.status = 'active' limit 1)
  );
$$;

create or replace function public.cp_is_platform_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (p.auth_user_id = auth.uid() or p.id = auth.uid() or lower(coalesce(p.email,'')) = lower(coalesce(auth.jwt() ->> 'email','')))
      and coalesce(p.status,'active') = 'active'
      and coalesce(p.marketplace_role, p.role) in ('platform_admin','admin')
  );
$$;

create or replace function public.cp_is_agency_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (p.auth_user_id = auth.uid() or p.id = auth.uid() or lower(coalesce(p.email,'')) = lower(coalesce(auth.jwt() ->> 'email','')))
      and coalesce(p.status,'active') = 'active'
      and coalesce(p.marketplace_role, p.role) = 'agency_admin'
  );
$$;

create or replace function public.cp_next_job_number()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prefix text := 'CPJ-' || to_char(now(), 'YYYYMMDD') || '-';
  v_next int;
begin
  select coalesce(max((regexp_match(job_number, '[0-9]+$'))[1]::int), 0) + 1
  into v_next
  from public.marketplace_jobs
  where job_number like v_prefix || '%';

  return v_prefix || lpad(v_next::text, 4, '0');
end;
$$;

-- -----------------------------------------------------------------------------
-- 5) Platform / agency onboarding RPCs
-- -----------------------------------------------------------------------------
create or replace function public.cp_bootstrap_platform_admin(
  p_email text,
  p_display_name text default 'Platform Admin',
  p_business_name text default 'Co Pilot Security Marketplace'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := coalesce(auth.uid(), public.cp_auth_user_id_for_email(p_email));
  v_email text := lower(trim(p_email));
  v_profile public.profiles%rowtype;
begin
  if exists (select 1 from public.profiles p where coalesce(p.marketplace_role, p.role) in ('platform_admin','admin') and lower(p.email) <> v_email) then
    raise exception 'Platform admin already exists.';
  end if;

  insert into public.profiles (id, auth_user_id, email, role, marketplace_role, display_name, status, created_at, updated_at)
  values (coalesce(v_uid, gen_random_uuid()), v_uid, v_email, 'platform_admin', 'platform_admin', coalesce(nullif(trim(p_display_name), ''), 'Platform Admin'), 'active', now(), now())
  on conflict (id) do update set auth_user_id = excluded.auth_user_id, email = excluded.email, role = 'platform_admin', marketplace_role = 'platform_admin', display_name = excluded.display_name, status = 'active', updated_at = now()
  returning * into v_profile;

  insert into public.business_settings (business_name, created_at, updated_at)
  select coalesce(nullif(trim(p_business_name), ''), 'Co Pilot Security Marketplace'), now(), now()
  where not exists (select 1 from public.business_settings);

  return jsonb_build_object('ok', true, 'profile', row_to_json(v_profile));
end;
$$;

create or replace function public.cp_submit_agency_signup(
  p_auth_user_id uuid default null,
  p_agency_name text default '',
  p_contact_name text default '',
  p_email text default '',
  p_phone text default '',
  p_license_state text default 'FL',
  p_license_number text default '',
  p_primary_city text default '',
  p_service_radius_miles numeric default 25,
  p_service_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := coalesce(p_auth_user_id, auth.uid(), public.cp_auth_user_id_for_email(p_email));
  v_email text := lower(trim(p_email));
  v_agency public.agencies%rowtype;
  v_profile public.profiles%rowtype;
begin
  if length(trim(p_agency_name)) < 2 then raise exception 'Agency name is required.'; end if;
  if length(v_email) < 5 then raise exception 'Agency email is required.'; end if;
  if length(trim(p_license_number)) < 2 then raise exception 'Security agency license number is required.'; end if;

  insert into public.agencies (
    agency_name, contact_name, contact_email, contact_phone, license_state, license_number,
    approval_status, verification_status, primary_city, primary_state, service_radius_miles, service_notes,
    created_at, updated_at
  ) values (
    trim(p_agency_name), trim(p_contact_name), v_email, coalesce(trim(p_phone), ''), upper(coalesce(nullif(trim(p_license_state), ''), 'FL')), trim(p_license_number),
    'pending', 'unverified', coalesce(trim(p_primary_city), ''), upper(coalesce(nullif(trim(p_license_state), ''), 'FL')), coalesce(p_service_radius_miles, 25), coalesce(trim(p_service_notes), ''),
    now(), now()
  )
  on conflict do nothing;

  select * into v_agency from public.agencies where lower(contact_email) = v_email order by created_at desc limit 1;

  if not found then
    raise exception 'Agency application could not be created.';
  end if;

  insert into public.profiles (id, auth_user_id, email, role, marketplace_role, display_name, phone, status, agency_id, created_at, updated_at)
  values (coalesce(v_uid, gen_random_uuid()), v_uid, v_email, 'agency_admin', 'agency_admin', coalesce(nullif(trim(p_contact_name), ''), trim(p_agency_name)), coalesce(trim(p_phone), ''), 'pending', v_agency.id, now(), now())
  on conflict (id) do update set auth_user_id = excluded.auth_user_id, email = excluded.email, role = 'agency_admin', marketplace_role = 'agency_admin', display_name = excluded.display_name, phone = excluded.phone, status = 'pending', agency_id = excluded.agency_id, updated_at = now()
  returning * into v_profile;

  insert into public.agency_members (agency_id, profile_id, member_role, status, created_at, updated_at)
  values (v_agency.id, v_profile.id, 'agency_admin', 'pending', now(), now())
  on conflict (agency_id, profile_id) do update set member_role = 'agency_admin', status = 'pending', updated_at = now();

  return jsonb_build_object('ok', true, 'agency', row_to_json(v_agency), 'profile', row_to_json(v_profile));
end;
$$;

create or replace function public.cp_platform_review_agency(
  p_agency_id uuid,
  p_status text,
  p_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_status text := lower(coalesce(nullif(trim(p_status), ''), 'pending'));
  v_profile public.profiles%rowtype := public.cp_current_profile();
  v_agency public.agencies%rowtype;
begin
  if not public.cp_is_platform_admin() then raise exception 'Only Platform Admin can review agencies.'; end if;
  if v_status not in ('approved','rejected','suspended','pending') then raise exception 'Invalid agency review status.'; end if;

  update public.agencies
  set approval_status = v_status,
      verification_status = case when v_status = 'approved' then 'verified' when v_status = 'rejected' then 'rejected' when v_status = 'suspended' then 'suspended' else verification_status end,
      platform_notes = coalesce(nullif(trim(p_notes), ''), platform_notes),
      approved_by = case when v_status = 'approved' then v_profile.id else approved_by end,
      approved_at = case when v_status = 'approved' then now() else approved_at end,
      rejected_at = case when v_status = 'rejected' then now() else rejected_at end,
      suspended_at = case when v_status = 'suspended' then now() else suspended_at end,
      updated_at = now()
  where id = p_agency_id
  returning * into v_agency;

  if not found then raise exception 'Agency not found.'; end if;

  update public.profiles set status = case when v_status = 'approved' then 'active' when v_status in ('rejected','suspended') then v_status else status end, updated_at = now()
  where agency_id = v_agency.id and coalesce(marketplace_role, role) = 'agency_admin';

  update public.agency_members set status = case when v_status = 'approved' then 'active' when v_status in ('rejected','suspended') then v_status else status end, updated_at = now()
  where agency_id = v_agency.id;

  return jsonb_build_object('ok', true, 'agency', row_to_json(v_agency));
end;
$$;

-- -----------------------------------------------------------------------------
-- 6) Job/event foundation RPCs
-- -----------------------------------------------------------------------------
create or replace function public.cp_record_job_event(
  p_job_id uuid,
  p_event_type text,
  p_title text default '',
  p_details text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_profile public.profiles%rowtype := public.cp_current_profile();
  v_job public.marketplace_jobs%rowtype;
  v_event public.job_events%rowtype;
begin
  select * into v_job from public.marketplace_jobs where id = p_job_id limit 1;
  if not found then raise exception 'Marketplace job not found.'; end if;

  insert into public.job_events (
    job_id, patrol_request_id, event_type, event_status, actor_profile_id, actor_agency_id,
    actor_role, actor_name, title, details, metadata, created_at
  ) values (
    v_job.id, v_job.patrol_request_id, p_event_type, v_job.current_status, v_profile.id, v_profile.agency_id,
    coalesce(v_profile.marketplace_role, v_profile.role, ''), coalesce(v_profile.display_name, v_profile.email, ''),
    coalesce(nullif(trim(p_title), ''), p_event_type), coalesce(p_details, ''), coalesce(p_metadata, '{}'::jsonb), now()
  ) returning * into v_event;

  return jsonb_build_object('ok', true, 'event', row_to_json(v_event));
end;
$$;

create or replace function public.cp_submit_patrol_request(
  p_property_id uuid,
  p_priority text default 'normal',
  p_instructions text default '',
  p_patrol_type text default 'standard',
  p_proof_preference text default 'photo',
  p_schedule_type text default 'on_demand',
  p_scheduled_for text default null,
  p_schedule_start_date text default null,
  p_schedule_end_date text default null,
  p_preferred_time_window text default '',
  p_recurrence_pattern text default '',
  p_recurrence_days text default '',
  p_schedule_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_profile public.profiles%rowtype := public.cp_current_profile();
  v_client public.clients%rowtype;
  v_property public.properties%rowtype;
  v_request public.patrol_requests%rowtype;
  v_job public.marketplace_jobs%rowtype;
  v_priority text := lower(coalesce(nullif(trim(p_priority), ''), 'normal'));
  v_patrol_type text := lower(coalesce(nullif(trim(p_patrol_type), ''), 'standard'));
  v_proof_preference text := lower(coalesce(nullif(trim(p_proof_preference), ''), 'photo'));
  v_schedule_type text := lower(coalesce(nullif(trim(p_schedule_type), ''), 'on_demand'));
  v_scheduled_for timestamptz := null;
  v_schedule_start_date date := null;
  v_schedule_end_date date := null;
begin
  if p_property_id is null then raise exception 'Select a saved property before requesting patrol.'; end if;

  select * into v_client from public.clients where auth_user_id = v_uid or lower(email) = v_email or id = v_profile.client_id limit 1;
  if not found then raise exception 'Approved client record not found.'; end if;

  select * into v_property from public.properties where id = p_property_id and client_id = v_client.id limit 1;
  if not found then raise exception 'You can only request patrol for your own saved property.'; end if;

  if v_priority not in ('normal','high','urgent') then v_priority := 'normal'; end if;
  if v_patrol_type not in ('standard','urgent','vacation_watch','suspicious_activity','alarm_response','custom','recurring') then v_patrol_type := 'standard'; end if;
  if v_proof_preference not in ('photo','video','photo_video','none') then v_proof_preference := 'photo'; end if;
  if v_schedule_type not in ('on_demand','scheduled','vacation_watch','recurring') then v_schedule_type := 'on_demand'; end if;

  begin if p_scheduled_for is not null and trim(p_scheduled_for) <> '' then v_scheduled_for := p_scheduled_for::timestamptz; end if; exception when others then v_scheduled_for := null; end;
  begin if p_schedule_start_date is not null and trim(p_schedule_start_date) <> '' then v_schedule_start_date := p_schedule_start_date::date; end if; exception when others then v_schedule_start_date := null; end;
  begin if p_schedule_end_date is not null and trim(p_schedule_end_date) <> '' then v_schedule_end_date := p_schedule_end_date::date; end if; exception when others then v_schedule_end_date := null; end;

  insert into public.patrol_requests (
    client_id, property_id, guard_id, status, current_status, priority, instructions,
    patrol_type, proof_preference, schedule_type, scheduled_for, schedule_start_date, schedule_end_date,
    preferred_time_window, recurrence_pattern, recurrence_days, schedule_notes,
    requested_at, created_at, updated_at
  ) values (
    v_client.id, v_property.id, null, 'open_marketplace', 'open_marketplace', v_priority, coalesce(p_instructions, ''),
    v_patrol_type, v_proof_preference, v_schedule_type, v_scheduled_for, v_schedule_start_date, v_schedule_end_date,
    coalesce(p_preferred_time_window, ''), coalesce(p_recurrence_pattern, ''), coalesce(p_recurrence_days, ''), coalesce(p_schedule_notes, ''),
    now(), now(), now()
  ) returning * into v_request;

  insert into public.marketplace_jobs (
    job_number, patrol_request_id, client_id, property_id, requested_by_profile_id,
    current_status, priority, patrol_type, proof_preference, request_notes,
    schedule_type, scheduled_for, schedule_start_date, schedule_end_date, preferred_time_window,
    recurrence_pattern, recurrence_days, schedule_notes, requested_at, created_at, updated_at
  ) values (
    public.cp_next_job_number(), v_request.id, v_client.id, v_property.id, v_profile.id,
    'open_marketplace', v_priority, v_patrol_type, v_proof_preference, coalesce(p_instructions, ''),
    v_schedule_type, v_scheduled_for, v_schedule_start_date, v_schedule_end_date, coalesce(p_preferred_time_window, ''),
    coalesce(p_recurrence_pattern, ''), coalesce(p_recurrence_days, ''), coalesce(p_schedule_notes, ''), now(), now(), now()
  ) returning * into v_job;

  update public.patrol_requests set marketplace_job_id = v_job.id, job_number = v_job.job_number, updated_at = now() where id = v_request.id returning * into v_request;

  perform public.cp_record_job_event(v_job.id, 'client_request', 'Client requested patrol', coalesce(v_property.label, 'Property') || ' · ' || coalesce(v_property.address, ''), jsonb_build_object('priority', v_priority, 'patrol_type', v_patrol_type));

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request), 'job', row_to_json(v_job), 'request_id', v_request.id, 'job_id', v_job.id);
end;
$$;

create or replace function public.cp_agency_accept_marketplace_job(p_job_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_profile public.profiles%rowtype := public.cp_current_profile();
  v_agency_id uuid := public.cp_current_agency_id();
  v_agency public.agencies%rowtype;
  v_job public.marketplace_jobs%rowtype;
begin
  if not public.cp_is_agency_admin() then raise exception 'Only approved agency admins can accept jobs.'; end if;
  if v_agency_id is null then raise exception 'Agency account is not linked to an agency.'; end if;

  select * into v_agency from public.agencies where id = v_agency_id limit 1;
  if not found then raise exception 'Agency not found.'; end if;
  if coalesce(v_agency.approval_status, '') <> 'approved' then raise exception 'Agency must be approved before accepting jobs.'; end if;

  select * into v_job from public.marketplace_jobs where id = p_job_id for update;
  if not found then raise exception 'Marketplace job not found.'; end if;
  if v_job.current_status not in ('open_marketplace','pending_marketplace','marketplace_open') then raise exception 'This job is no longer open.'; end if;

  update public.marketplace_jobs
  set accepted_agency_id = v_agency.id,
      current_status = 'agency_accepted',
      agency_accepted_at = now(),
      updated_at = now()
  where id = v_job.id
  returning * into v_job;

  insert into public.marketplace_job_claims (job_id, agency_id, status, accepted_by_profile_id, accepted_at, created_at)
  values (v_job.id, v_agency.id, 'accepted', v_profile.id, now(), now())
  on conflict (job_id, agency_id) do update set status = 'accepted', accepted_by_profile_id = excluded.accepted_by_profile_id, accepted_at = now();

  update public.patrol_requests
  set accepted_agency_id = v_agency.id,
      agency_id = v_agency.id,
      status = 'agency_accepted',
      current_status = 'agency_accepted',
      updated_at = now()
  where id = v_job.patrol_request_id;

  perform public.cp_record_job_event(v_job.id, 'agency_accepted', 'Agency accepted job', v_agency.agency_name || ' accepted ' || v_job.job_number, jsonb_build_object('agency_id', v_agency.id));

  return jsonb_build_object('ok', true, 'job', row_to_json(v_job), 'agency', row_to_json(v_agency));
end;
$$;

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

  select * into v_job from public.marketplace_jobs where id = p_job_id and accepted_agency_id = v_agency_id for update;
  if not found then raise exception 'Job is not accepted by your agency.'; end if;

  select * into v_guard from public.guards where id = p_guard_id and agency_id = v_agency_id limit 1;
  if not found then raise exception 'Guard is not part of your agency.'; end if;

  update public.marketplace_jobs set assigned_guard_id = v_guard.id, current_status = 'guard_assigned', guard_assigned_at = now(), updated_at = now() where id = v_job.id returning * into v_job;
  update public.patrol_requests set guard_id = v_guard.id, status = 'assigned', current_status = 'guard_assigned', assigned_at = now(), updated_at = now() where id = v_job.patrol_request_id;

  perform public.cp_record_job_event(v_job.id, 'guard_assigned', 'Agency assigned guard', coalesce(v_guard.name, v_guard.email, 'Guard') || ' assigned to ' || v_job.job_number, jsonb_build_object('guard_id', v_guard.id));

  return jsonb_build_object('ok', true, 'job', row_to_json(v_job), 'guard', row_to_json(v_guard));
end;
$$;

-- -----------------------------------------------------------------------------
-- 7) Global app data loader — returns old v3 fields PLUS v4 fields
-- -----------------------------------------------------------------------------
create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
  v_agency_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(coalesce(email,'')) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile found for this login.');
  end if;

  v_role := coalesce(v_profile.marketplace_role, v_profile.role);
  v_client_id := coalesce(v_profile.client_id, (select c.id from public.clients c where c.auth_user_id = v_uid or lower(c.email) = v_email limit 1));
  v_guard_id := coalesce(v_profile.guard_id, (select g.id from public.guards g where g.auth_user_id = v_uid or lower(g.email) = v_email limit 1));
  v_agency_id := coalesce(v_profile.agency_id, (select am.agency_id from public.agency_members am where am.profile_id = v_profile.id and am.status in ('active','pending') limit 1));

  if v_role in ('platform_admin','admin') then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g), '[]'::jsonb),
      'agencies', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.agencies a), '[]'::jsonb),
      'agencyMembers', coalesce((select jsonb_agg(row_to_json(am) order by am.created_at desc) from public.agency_members am), '[]'::jsonb),
      'marketplaceJobs', coalesce((select jsonb_agg(row_to_json(x) order by x.created_at desc) from (select j.*, p.label as property_label, p.address as property_address, c.name as client_name, a.agency_name as accepted_agency_name, g.name as assigned_guard_name from public.marketplace_jobs j left join public.properties p on p.id=j.property_id left join public.clients c on c.id=j.client_id left join public.agencies a on a.id=j.accepted_agency_id left join public.guards g on g.id=j.assigned_guard_id) x), '[]'::jsonb),
      'jobEvents', coalesce((select jsonb_agg(row_to_json(e) order by e.created_at desc) from public.job_events e), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.created_at desc) from public.patrol_requests r), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.created_at desc) from public.patrol_reports pr), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.target_role in ('admin','platform_admin')), '[]'::jsonb),
      'patrolActivity', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.cp_patrol_activity_log a), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m), '[]'::jsonb)
    );
  elsif v_role = 'agency_admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select j.client_id from public.marketplace_jobs j where j.accepted_agency_id = v_agency_id)), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g where g.agency_id = v_agency_id), '[]'::jsonb),
      'agencies', coalesce((select jsonb_agg(row_to_json(a)) from public.agencies a where a.id = v_agency_id), '[]'::jsonb),
      'agencyMembers', coalesce((select jsonb_agg(row_to_json(am) order by am.created_at desc) from public.agency_members am where am.agency_id = v_agency_id), '[]'::jsonb),
      'marketplaceJobs', coalesce((select jsonb_agg(row_to_json(x) order by x.created_at desc) from (select j.*, p.label as property_label, p.address as property_address, c.name as client_name, a.agency_name as accepted_agency_name, g.name as assigned_guard_name from public.marketplace_jobs j left join public.properties p on p.id=j.property_id left join public.clients c on c.id=j.client_id left join public.agencies a on a.id=j.accepted_agency_id left join public.guards g on g.id=j.assigned_guard_id where j.current_status in ('open_marketplace','pending_marketplace','marketplace_open') or j.accepted_agency_id = v_agency_id) x), '[]'::jsonb),
      'jobEvents', coalesce((select jsonb_agg(row_to_json(e) order by e.created_at desc) from public.job_events e where e.actor_agency_id = v_agency_id or e.job_id in (select id from public.marketplace_jobs where accepted_agency_id = v_agency_id)), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select j.property_id from public.marketplace_jobs j where j.accepted_agency_id = v_agency_id or j.current_status in ('open_marketplace','pending_marketplace','marketplace_open'))), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.created_at desc) from public.patrol_requests r where r.accepted_agency_id = v_agency_id or r.status in ('open_marketplace','pending_marketplace','marketplace_open')), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.marketplace_job_id in (select id from public.marketplace_jobs where accepted_agency_id = v_agency_id)), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.created_at desc) from public.patrol_reports pr where pr.agency_id = v_agency_id), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.target_role = 'agency_admin'), '[]'::jsonb),
      'patrolActivity', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.cp_patrol_activity_log a where a.request_id in (select patrol_request_id from public.marketplace_jobs where accepted_agency_id = v_agency_id)), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t where t.guard_id in (select id from public.guards where agency_id = v_agency_id)), '[]'::jsonb),
      'messages', '[]'::jsonb
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id = v_client_id or c.auth_user_id = v_uid or lower(c.email) = v_email), '[]'::jsonb),
      'guards', '[]'::jsonb,
      'agencies', coalesce((select jsonb_agg(row_to_json(a) order by a.agency_name) from public.agencies a where a.id in (select j.accepted_agency_id from public.marketplace_jobs j where j.client_id = v_client_id)), '[]'::jsonb),
      'agencyMembers', '[]'::jsonb,
      'marketplaceJobs', coalesce((select jsonb_agg(row_to_json(x) order by x.created_at desc) from (select j.*, p.label as property_label, p.address as property_address, a.agency_name as accepted_agency_name from public.marketplace_jobs j left join public.properties p on p.id=j.property_id left join public.agencies a on a.id=j.accepted_agency_id where j.client_id = v_client_id) x), '[]'::jsonb),
      'jobEvents', coalesce((select jsonb_agg(row_to_json(e) order by e.created_at desc) from public.job_events e where e.job_id in (select id from public.marketplace_jobs where client_id = v_client_id)), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.request_id in (select r.id from public.patrol_requests r where r.client_id = v_client_id)), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.created_at desc) from public.patrol_reports pr where pr.client_id = v_client_id), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.client_id = v_client_id or n.target_role = 'client'), '[]'::jsonb),
      'patrolActivity', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.cp_patrol_activity_log a where a.request_id in (select r.id from public.patrol_requests r where r.client_id = v_client_id)), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t where t.client_id = v_client_id), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m where m.thread_id in (select t.id from public.cp_message_threads t where t.client_id = v_client_id)), '[]'::jsonb)
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select j.client_id from public.marketplace_jobs j where j.assigned_guard_id = v_guard_id)), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id = v_guard_id or g.auth_user_id = v_uid or lower(g.email) = v_email), '[]'::jsonb),
      'agencies', coalesce((select jsonb_agg(row_to_json(a)) from public.agencies a where a.id = v_agency_id), '[]'::jsonb),
      'agencyMembers', '[]'::jsonb,
      'marketplaceJobs', coalesce((select jsonb_agg(row_to_json(x) order by x.created_at desc) from (select j.*, p.label as property_label, p.address as property_address, c.name as client_name, a.agency_name as accepted_agency_name, g.name as assigned_guard_name from public.marketplace_jobs j left join public.properties p on p.id=j.property_id left join public.clients c on c.id=j.client_id left join public.agencies a on a.id=j.accepted_agency_id left join public.guards g on g.id=j.assigned_guard_id where j.assigned_guard_id = v_guard_id) x), '[]'::jsonb),
      'jobEvents', coalesce((select jsonb_agg(row_to_json(e) order by e.created_at desc) from public.job_events e where e.job_id in (select id from public.marketplace_jobs where assigned_guard_id = v_guard_id)), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select j.property_id from public.marketplace_jobs j where j.assigned_guard_id = v_guard_id)), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id or r.id in (select patrol_request_id from public.marketplace_jobs where assigned_guard_id = v_guard_id)), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.marketplace_job_id in (select id from public.marketplace_jobs where assigned_guard_id = v_guard_id)), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.created_at desc) from public.patrol_reports pr where pr.guard_id = v_guard_id), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.guard_id = v_guard_id or n.target_role = 'guard'), '[]'::jsonb),
      'patrolActivity', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.cp_patrol_activity_log a where a.request_id in (select patrol_request_id from public.marketplace_jobs where assigned_guard_id = v_guard_id)), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t where t.guard_id = v_guard_id), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m where m.thread_id in (select t.id from public.cp_message_threads t where t.guard_id = v_guard_id)), '[]'::jsonb)
    );
  end if;

  return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
end;
$$;

-- -----------------------------------------------------------------------------
-- 8) RLS/grants — RPCs are security definer; policies protect direct table access
-- -----------------------------------------------------------------------------
alter table public.agencies enable row level security;
alter table public.agency_members enable row level security;
alter table public.agency_service_areas enable row level security;
alter table public.marketplace_jobs enable row level security;
alter table public.job_events enable row level security;
alter table public.marketplace_job_claims enable row level security;

drop policy if exists agencies_platform_all on public.agencies;
create policy agencies_platform_all on public.agencies for all using (public.cp_is_platform_admin()) with check (public.cp_is_platform_admin());
drop policy if exists agencies_own_select on public.agencies;
create policy agencies_own_select on public.agencies for select using (id = public.cp_current_agency_id());

drop policy if exists agency_members_platform_all on public.agency_members;
create policy agency_members_platform_all on public.agency_members for all using (public.cp_is_platform_admin()) with check (public.cp_is_platform_admin());
drop policy if exists agency_members_own_select on public.agency_members;
create policy agency_members_own_select on public.agency_members for select using (agency_id = public.cp_current_agency_id());

drop policy if exists marketplace_jobs_platform_all on public.marketplace_jobs;
create policy marketplace_jobs_platform_all on public.marketplace_jobs for all using (public.cp_is_platform_admin()) with check (public.cp_is_platform_admin());
drop policy if exists marketplace_jobs_agency_select on public.marketplace_jobs;
create policy marketplace_jobs_agency_select on public.marketplace_jobs for select using (current_status in ('open_marketplace','pending_marketplace','marketplace_open') or accepted_agency_id = public.cp_current_agency_id());
drop policy if exists marketplace_jobs_client_select on public.marketplace_jobs;
create policy marketplace_jobs_client_select on public.marketplace_jobs for select using (client_id in (select c.id from public.clients c where c.auth_user_id = auth.uid() or lower(c.email)=lower(coalesce(auth.jwt() ->> 'email',''))));

drop policy if exists job_events_platform_all on public.job_events;
create policy job_events_platform_all on public.job_events for all using (public.cp_is_platform_admin()) with check (public.cp_is_platform_admin());
drop policy if exists job_events_related_select on public.job_events;
create policy job_events_related_select on public.job_events for select using (job_id in (select j.id from public.marketplace_jobs j where j.accepted_agency_id = public.cp_current_agency_id() or j.client_id in (select c.id from public.clients c where c.auth_user_id = auth.uid() or lower(c.email)=lower(coalesce(auth.jwt() ->> 'email','')))));

grant usage on schema public to anon, authenticated;
grant select, insert, update on public.agencies to authenticated;
grant select, insert, update on public.agency_members to authenticated;
grant select, insert, update on public.agency_service_areas to authenticated;
grant select, insert, update on public.marketplace_jobs to authenticated;
grant select, insert, update on public.job_events to authenticated;
grant select, insert, update on public.marketplace_job_claims to authenticated;

grant execute on function public.cp_bootstrap_platform_admin(text, text, text) to authenticated;
grant execute on function public.cp_submit_agency_signup(uuid, text, text, text, text, text, text, text, numeric, text) to authenticated;
grant execute on function public.cp_platform_review_agency(uuid, text, text) to authenticated;
grant execute on function public.cp_submit_patrol_request(uuid, text, text, text, text, text, text, text, text, text, text, text, text) to authenticated;
grant execute on function public.cp_agency_accept_marketplace_job(uuid) to authenticated;
grant execute on function public.cp_agency_assign_guard_to_job(uuid, uuid) to authenticated;
grant execute on function public.cp_record_job_event(uuid, text, text, text, jsonb) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;

-- storage buckets for agency documents and proof media
insert into storage.buckets (id, name, public)
values ('agency-documents', 'agency-documents', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('patrol-proof', 'patrol-proof', true)
on conflict (id) do nothing;

notify pgrst, 'reload schema';
