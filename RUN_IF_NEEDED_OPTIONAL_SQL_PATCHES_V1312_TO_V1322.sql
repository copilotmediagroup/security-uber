-- Co Pilot Security Patrol — Optional SQL Patches v1.3.12 through v1.3.22
-- Consolidated to keep the continuation package under 20 files.
-- Run ONLY if the feature is needed and not already installed.
-- Sections are idempotent / safe to rerun as originally provided where possible.

-- ============================================================
-- SECTION 1: v1.3.12 Report Archive User Status
-- Enables deactivate/reactivate controls for guards/clients if needed.
-- Original file: RUN_IF_NEEDED_V1312_REPORT_ARCHIVE_USER_STATUS.sql
-- ============================================================
-- v1.3.12 optional user status controls
-- Run once if you want Dispatch deactivate/reactivate buttons to work.
-- Report archive/download features do not require SQL changes.

alter table public.guards add column if not exists status text default 'active';
alter table public.clients add column if not exists status text default 'active';
alter table public.profiles add column if not exists status text default 'active';

create or replace function public.cp_admin_set_guard_status(p_guard_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(coalesce(nullif(trim(p_status), ''), 'active'));
begin
  if not public.cp_is_admin() then
    raise exception 'Only Dispatch can update guard status.';
  end if;

  if v_status not in ('active','inactive') then
    raise exception 'Invalid guard status.';
  end if;

  update public.guards
  set status = v_status,
      availability_status = case when v_status = 'inactive' then 'offline' else coalesce(availability_status, 'offline') end,
      is_available = case when v_status = 'inactive' then false else coalesce(is_available, false) end,
      updated_at = now()
  where id = p_guard_id;

  update public.profiles
  set status = v_status,
      updated_at = now()
  where guard_id = p_guard_id
     or auth_user_id in (select auth_user_id from public.guards where id = p_guard_id)
     or lower(coalesce(email,'')) in (select lower(coalesce(email,'')) from public.guards where id = p_guard_id);

  return jsonb_build_object('ok', true, 'guard_id', p_guard_id, 'status', v_status);
end;
$$;

create or replace function public.cp_admin_set_client_status(p_client_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(coalesce(nullif(trim(p_status), ''), 'active'));
begin
  if not public.cp_is_admin() then
    raise exception 'Only Dispatch can update client status.';
  end if;

  if v_status not in ('active','inactive') then
    raise exception 'Invalid client status.';
  end if;

  update public.clients
  set status = v_status,
      updated_at = now()
  where id = p_client_id;

  update public.profiles
  set status = v_status,
      updated_at = now()
  where client_id = p_client_id
     or auth_user_id in (select auth_user_id from public.clients where id = p_client_id)
     or lower(coalesce(email,'')) in (select lower(coalesce(email,'')) from public.clients where id = p_client_id);

  return jsonb_build_object('ok', true, 'client_id', p_client_id, 'status', v_status);
end;
$$;

grant execute on function public.cp_admin_set_guard_status(uuid, text) to authenticated;
grant execute on function public.cp_admin_set_client_status(uuid, text) to authenticated;

-- ============================================================
-- SECTION 2: v1.3.13 Company Branding
-- Enables company branding/contact setting saves and company logo upload.
-- Original file: RUN_IF_NEEDED_V1313_COMPANY_BRANDING.sql
-- ============================================================
-- Co Pilot Security Patrol v1.3.13 Company Branding Settings
-- Run once in Supabase SQL Editor if you want Dispatch to upload company logo
-- and update company phone/email/address/website from the Settings screen.
-- No pricing. No SMS/email. No invite codes. No claim codes. No Edge Functions.

create extension if not exists pgcrypto;

alter table public.business_settings add column if not exists logo_url text default '';
alter table public.business_settings add column if not exists company_phone text default '';
alter table public.business_settings add column if not exists company_email text default '';
alter table public.business_settings add column if not exists company_address text default '';
alter table public.business_settings add column if not exists company_website text default '';
alter table public.business_settings add column if not exists updated_at timestamptz default now();

insert into public.business_settings (business_name, logo_url, created_at, updated_at)
select 'Co Pilot Security', '', now(), now()
where not exists (select 1 from public.business_settings);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'company-branding',
  'company-branding',
  true,
  8388608,
  array['image/jpeg','image/jpg','image/png','image/webp','image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "cp company branding public read" on storage.objects;
drop policy if exists "cp company branding authenticated upload" on storage.objects;
drop policy if exists "cp company branding owner update" on storage.objects;
drop policy if exists "cp company branding owner delete" on storage.objects;

create policy "cp company branding public read"
on storage.objects
for select
to public
using (bucket_id = 'company-branding');

create policy "cp company branding authenticated upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'company-branding');

create policy "cp company branding owner update"
on storage.objects
for update
to authenticated
using (bucket_id = 'company-branding' and owner = auth.uid())
with check (bucket_id = 'company-branding' and owner = auth.uid());

create policy "cp company branding owner delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'company-branding' and owner = auth.uid());

create or replace function public.cp_update_business_branding(
  p_business_name text default 'Co Pilot Security',
  p_logo_url text default '',
  p_company_phone text default '',
  p_company_email text default '',
  p_company_address text default '',
  p_company_website text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_profile public.profiles%rowtype;
  v_id uuid;
begin
  select * into v_profile from public.profiles where auth_user_id = v_uid limit 1;
  if v_profile.id is null or v_profile.role <> 'admin' then
    raise exception 'Only Dispatch can update company branding.';
  end if;

  select id into v_id from public.business_settings order by created_at asc limit 1;

  if v_id is null then
    insert into public.business_settings (
      business_name, logo_url, company_phone, company_email, company_address, company_website, created_at, updated_at
    ) values (
      coalesce(nullif(trim(p_business_name), ''), 'Co Pilot Security'),
      coalesce(p_logo_url, ''),
      coalesce(p_company_phone, ''),
      lower(coalesce(p_company_email, '')),
      coalesce(p_company_address, ''),
      coalesce(p_company_website, ''),
      now(),
      now()
    ) returning id into v_id;
  else
    update public.business_settings
    set business_name = coalesce(nullif(trim(p_business_name), ''), business_name),
        logo_url = coalesce(p_logo_url, logo_url, ''),
        company_phone = coalesce(p_company_phone, ''),
        company_email = lower(coalesce(p_company_email, '')),
        company_address = coalesce(p_company_address, ''),
        company_website = coalesce(p_company_website, ''),
        updated_at = now()
    where id = v_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb)
  );
end;
$$;

grant execute on function public.cp_update_business_branding(text,text,text,text,text,text) to authenticated;

notify pgrst, 'reload schema';

-- ============================================================
-- SECTION 3: v1.3.17 Public Branding
-- REQUIRED if logged-out/login page should load saved logo/branding.
-- Original file: RUN_IF_NEEDED_V1317_PUBLIC_BRANDING.sql
-- ============================================================
-- Co Pilot Security Patrol v1.3.17 Public Branding Loader
-- Run once in Supabase SQL Editor.
-- Purpose: allow the logged-out login/sign-up pages to display saved company branding.
-- No pricing. No SMS/email. No invite codes. No claim codes. No Edge Functions.

create extension if not exists pgcrypto;

alter table public.business_settings add column if not exists business_name text default 'Co Pilot Security';
alter table public.business_settings add column if not exists logo_url text default '';
alter table public.business_settings add column if not exists company_phone text default '';
alter table public.business_settings add column if not exists company_email text default '';
alter table public.business_settings add column if not exists company_address text default '';
alter table public.business_settings add column if not exists company_website text default '';
alter table public.business_settings add column if not exists updated_at timestamptz default now();

insert into public.business_settings (business_name, logo_url, created_at, updated_at)
select 'Co Pilot Security', '', now(), now()
where not exists (select 1 from public.business_settings);

create or replace function public.cp_get_public_business_branding()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings jsonb;
begin
  select to_jsonb(s) into v_settings
  from (
    select
      business_name,
      logo_url,
      company_phone,
      company_email,
      company_address,
      company_website,
      updated_at
    from public.business_settings
    order by created_at asc
    limit 1
  ) s;

  return jsonb_build_object(
    'ok', true,
    'settings', case when v_settings is null then '[]'::jsonb else jsonb_build_array(v_settings) end
  );
end;
$$;

grant execute on function public.cp_get_public_business_branding() to anon;
grant execute on function public.cp_get_public_business_branding() to authenticated;

notify pgrst, 'reload schema';

-- ============================================================
-- SECTION 4: v1.3.22 Download Message Transcript
-- Optional only if Dispatch/Guard job messages should be included in downloaded reports.
-- Original file: RUN_IF_NEEDED_V1322_DOWNLOAD_MESSAGE_TRANSCRIPT.sql
-- ============================================================
-- Co Pilot Security Patrol v1.3.22
-- OPTIONAL ONLY: enables the Dispatch checkbox that snapshots Dispatch/Guard job-window messages
-- for downloaded reports only. Normal timestamp download transparency does not require this SQL.

alter table public.patrol_reports
  add column if not exists include_job_messages boolean not null default false;

alter table public.patrol_reports
  add column if not exists job_message_transcript jsonb not null default '[]'::jsonb;

create index if not exists patrol_reports_include_job_messages_idx
  on public.patrol_reports(include_job_messages);

create or replace function public.cp_admin_save_patrol_report(
  p_request_id uuid,
  p_final_notes text default '',
  p_release boolean default false,
  p_include_job_messages boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.patrol_requests%rowtype;
  v_report public.patrol_reports%rowtype;
  v_existing public.patrol_reports%rowtype;
  v_status text := case when coalesce(p_release, false) then 'released' else 'draft' end;
  v_actor_name text := public.cp_current_actor_name();
  v_transcript jsonb := '[]'::jsonb;
  v_window_start timestamptz;
  v_window_end timestamptz;
begin
  if not public.cp_is_admin() then
    raise exception 'Only admin can save patrol reports.';
  end if;

  if p_request_id is null then
    raise exception 'Select a completed patrol request before saving report.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
  limit 1;

  if not found then
    raise exception 'Patrol request not found.';
  end if;

  if coalesce(v_request.status, '') <> 'completed' then
    raise exception 'A patrol must be completed before creating a final report.';
  end if;

  select * into v_existing
  from public.patrol_reports
  where request_id = p_request_id
  limit 1;

  if found and coalesce(v_existing.status, '') = 'released' and not coalesce(p_release, false) then
    v_status := 'released';
  end if;

  v_window_start := coalesce(v_request.assigned_at, v_request.requested_at, v_request.created_at, now() - interval '30 days');
  v_window_end := coalesce(v_request.completed_at, now()) + interval '24 hours';

  if coalesce(p_include_job_messages, false) then
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'sender_role', coalesce(nullif(trim(m.sender_role), ''), 'user'),
        'sender_name', coalesce(nullif(trim(m.sender_name), ''), 'User'),
        'body', coalesce(m.body, ''),
        'created_at', m.created_at
      ) order by m.created_at asc
    ), '[]'::jsonb)
    into v_transcript
    from public.cp_messages m
    join public.cp_message_threads t on t.id = m.thread_id
    where t.guard_id = v_request.guard_id
      and t.client_id is null
      and m.created_at >= v_window_start
      and m.created_at <= v_window_end
      and coalesce(m.body, '') <> '';
  end if;

  insert into public.patrol_reports (
    id, request_id, admin_id, final_notes, status, include_job_messages, job_message_transcript, created_at, updated_at, released_at
  ) values (
    gen_random_uuid(),
    p_request_id,
    public.cp_current_uid(),
    coalesce(p_final_notes, ''),
    v_status,
    coalesce(p_include_job_messages, false),
    case when coalesce(p_include_job_messages, false) then v_transcript else '[]'::jsonb end,
    now(),
    now(),
    case when coalesce(p_release, false) then now() else null end
  )
  on conflict (request_id) do update
  set admin_id = excluded.admin_id,
      final_notes = excluded.final_notes,
      include_job_messages = excluded.include_job_messages,
      job_message_transcript = excluded.job_message_transcript,
      status = case
        when public.patrol_reports.status = 'released' and not coalesce(p_release, false) then 'released'
        when coalesce(p_release, false) then 'released'
        else 'draft'
      end,
      updated_at = now(),
      released_at = case
        when coalesce(p_release, false) then coalesce(public.patrol_reports.released_at, now())
        else public.patrol_reports.released_at
      end
  returning * into v_report;

  perform public.cp_add_patrol_activity(
    p_request_id, 'admin', public.cp_current_uid(), v_actor_name,
    case when coalesce(p_release, false) then 'report_released' else 'report_draft_saved' end,
    case when coalesce(p_release, false) then 'Dispatch released final report' else 'Dispatch saved report draft' end,
    case
      when coalesce(p_release, false) and coalesce(p_include_job_messages, false) then 'Final report is ready for the client. Downloaded report exports include selected Dispatch/Guard job messages.'
      when coalesce(p_release, false) then 'Final report is ready for the client.'
      when coalesce(p_include_job_messages, false) then 'Report draft saved. Downloaded report exports include selected Dispatch/Guard job messages.'
      else 'Report draft was saved.'
    end
  );

  if coalesce(p_release, false) then
    perform public.cp_create_notification(
      'client', v_request.client_id, v_request.guard_id, p_request_id,
      'Final report ready',
      'Your patrol report has been released.'
    );
  end if;

  return jsonb_build_object('ok', true, 'report', row_to_json(v_report));
end;
$$;

grant execute on function public.cp_admin_save_patrol_report(uuid, text, boolean, boolean) to authenticated;
