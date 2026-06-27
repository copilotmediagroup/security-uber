-- Co Pilot Security Marketplace v4.0.1 — Agency Job Board SQL Patch
-- Run after RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql.
-- Adds persistent agency job decline support without changing global open marketplace job status.

alter table public.marketplace_job_claims add column if not exists declined_at timestamptz;
alter table public.marketplace_job_claims add column if not exists declined_by_profile_id uuid references public.profiles(id) on delete set null;

create index if not exists marketplace_job_claims_declined_idx on public.marketplace_job_claims(agency_id, status, declined_at desc);

create or replace function public.cp_agency_decline_marketplace_job(p_job_id uuid, p_response_notes text default '')
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
  if not public.cp_is_agency_admin() then
    raise exception 'Only approved agency admins can decline jobs.';
  end if;
  if v_agency_id is null then
    raise exception 'Agency account is not linked to an agency.';
  end if;

  select * into v_agency from public.agencies where id = v_agency_id limit 1;
  if not found then raise exception 'Agency not found.'; end if;
  if coalesce(v_agency.approval_status, '') <> 'approved' then
    raise exception 'Agency must be approved before declining jobs.';
  end if;

  select * into v_job from public.marketplace_jobs where id = p_job_id for update;
  if not found then raise exception 'Marketplace job not found.'; end if;
  if v_job.current_status not in ('open_marketplace','pending_marketplace','marketplace_open') then
    raise exception 'This job is no longer open.';
  end if;
  if v_job.accepted_agency_id is not null then
    raise exception 'This job is already locked to an agency.';
  end if;

  insert into public.marketplace_job_claims (
    job_id, agency_id, status, response_notes, declined_by_profile_id, declined_at, created_at
  ) values (
    v_job.id, v_agency.id, 'declined', coalesce(p_response_notes, ''), v_profile.id, now(), now()
  )
  on conflict (job_id, agency_id) do update set
    status = 'declined',
    response_notes = excluded.response_notes,
    declined_by_profile_id = excluded.declined_by_profile_id,
    declined_at = now();

  insert into public.job_events (
    job_id, patrol_request_id, event_type, event_status, actor_profile_id, actor_agency_id,
    actor_role, actor_name, title, details, metadata, created_at
  ) values (
    v_job.id, v_job.patrol_request_id, 'agency_declined', 'declined', v_profile.id, v_agency.id,
    coalesce(v_profile.marketplace_role, v_profile.role, 'agency_admin'),
    coalesce(v_profile.display_name, v_profile.email, v_agency.agency_name),
    'Agency declined job',
    v_agency.agency_name || ' declined ' || v_job.job_number,
    jsonb_build_object('agency_id', v_agency.id, 'response_notes', coalesce(p_response_notes, '')),
    now()
  );

  return jsonb_build_object('ok', true, 'job_id', v_job.id, 'agency_id', v_agency.id, 'status', 'declined');
end;
$$;

grant execute on function public.cp_agency_decline_marketplace_job(uuid, text) to authenticated;

notify pgrst, 'reload schema';
