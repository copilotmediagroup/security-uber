
-- Co Pilot Security Marketplace v4.0.11
-- GUARD MARKETPLACE JOB FLOW
-- Run after v4.0.10. This patch lets assigned agency guards move marketplace_jobs
-- through the field lifecycle and attach proof directly to marketplace_jobs.

alter table public.marketplace_jobs add column if not exists en_route_at timestamptz;
alter table public.marketplace_jobs add column if not exists arrived_at timestamptz;
create index if not exists marketplace_jobs_guard_lifecycle_idx on public.marketplace_jobs(assigned_guard_id, current_status, updated_at desc);

create or replace function public.cp_guard_update_marketplace_job_status(p_job_id uuid, p_next_status text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_guard_id uuid := public.cp_current_guard_id();
  v_guard public.guards%rowtype;
  v_job public.marketplace_jobs%rowtype;
  v_next text := lower(coalesce(p_next_status, ''));
  v_old_index int := 0;
  v_new_index int := 0;
  v_title text := '';
begin
  if v_guard_id is null then
    raise exception 'Approved guard record not found.';
  end if;

  select * into v_guard from public.guards where id = v_guard_id limit 1;

  select * into v_job
  from public.marketplace_jobs
  where id = p_job_id
    and assigned_guard_id = v_guard_id
  for update;

  if not found then
    raise exception 'This marketplace job is not assigned to you.';
  end if;

  if v_next not in ('guard_accepted','en_route','arrived','in_progress','proof_uploaded','completed') then
    raise exception 'Invalid marketplace guard status.';
  end if;

  v_old_index := case lower(coalesce(v_job.current_status, 'guard_assigned'))
    when 'guard_assigned' then 1
    when 'assigned' then 1
    when 'guard_accepted' then 2
    when 'accepted' then 2
    when 'en_route' then 3
    when 'arrived' then 4
    when 'in_progress' then 5
    when 'active' then 5
    when 'proof_uploaded' then 6
    when 'completed' then 7
    when 'report_published' then 8
    when 'published' then 8
    else 1
  end;

  v_new_index := case v_next
    when 'guard_accepted' then 2
    when 'en_route' then 3
    when 'arrived' then 4
    when 'in_progress' then 5
    when 'proof_uploaded' then 6
    when 'completed' then 7
    else 1
  end;

  if v_old_index >= 7 then
    raise exception 'This marketplace job is already completed.';
  end if;

  if v_new_index < v_old_index then
    raise exception 'This marketplace job cannot move backward.';
  end if;

  update public.marketplace_jobs
  set current_status = v_next,
      guard_accepted_at = case when v_next in ('guard_accepted','en_route','arrived','in_progress','proof_uploaded','completed') then coalesce(guard_accepted_at, now()) else guard_accepted_at end,
      en_route_at = case when v_next in ('en_route','arrived','in_progress','proof_uploaded','completed') then coalesce(en_route_at, now()) else en_route_at end,
      arrived_at = case when v_next in ('arrived','in_progress','proof_uploaded','completed') then coalesce(arrived_at, now()) else arrived_at end,
      started_at = case when v_next in ('in_progress','proof_uploaded','completed') then coalesce(started_at, now()) else started_at end,
      proof_uploaded_at = case when v_next in ('proof_uploaded','completed') then coalesce(proof_uploaded_at, now()) else proof_uploaded_at end,
      completed_at = case when v_next = 'completed' then coalesce(completed_at, now()) else completed_at end,
      updated_at = now()
  where id = v_job.id
  returning * into v_job;

  if v_job.patrol_request_id is not null then
    update public.patrol_requests
    set status = case
          when v_next in ('guard_accepted','en_route') then 'accepted'
          when v_next in ('arrived','in_progress','proof_uploaded') then 'in_progress'
          when v_next = 'completed' then 'completed'
          else status
        end,
        current_status = v_next,
        accepted_at = case when v_next in ('guard_accepted','en_route','arrived','in_progress','proof_uploaded','completed') then coalesce(accepted_at, now()) else accepted_at end,
        started_at = case when v_next in ('arrived','in_progress','proof_uploaded','completed') then coalesce(started_at, now()) else started_at end,
        completed_at = case when v_next = 'completed' then coalesce(completed_at, now()) else completed_at end,
        updated_at = now()
    where id = v_job.patrol_request_id;
  end if;

  v_title := case v_next
    when 'guard_accepted' then 'Guard accepted marketplace job'
    when 'en_route' then 'Guard en route to assignment'
    when 'arrived' then 'Guard arrived on site'
    when 'in_progress' then 'Guard started patrol'
    when 'proof_uploaded' then 'Guard uploaded proof'
    when 'completed' then 'Guard completed marketplace job'
    else 'Guard marketplace job update'
  end;

  insert into public.job_events (
    job_id, patrol_request_id, event_type, event_status,
    actor_profile_id, actor_agency_id, actor_guard_id, actor_role, actor_name,
    title, details, metadata, created_at
  ) values (
    v_job.id, v_job.patrol_request_id, v_next, v_next,
    null, v_job.accepted_agency_id, v_guard_id, 'guard', coalesce(v_guard.name, v_guard.email, 'Guard'),
    v_title, coalesce(v_guard.name, v_guard.email, 'Guard') || ' updated ' || v_job.job_number || ' to ' || v_next,
    jsonb_build_object('source','v4.0.11_guard_marketplace_job_flow','guard_id',v_guard_id), now()
  );

  return jsonb_build_object('ok', true, 'job', row_to_json(v_job), 'guard', row_to_json(v_guard));
end;
$$;

create or replace function public.cp_guard_register_marketplace_proof(
  p_job_id uuid,
  p_bucket_id text,
  p_object_path text,
  p_file_name text,
  p_file_type text,
  p_file_size bigint,
  p_public_url text,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_guard_id uuid := public.cp_current_guard_id();
  v_guard public.guards%rowtype;
  v_job public.marketplace_jobs%rowtype;
  v_proof public.patrol_proof_items%rowtype;
  v_kind text := lower(coalesce(p_file_type, ''));
begin
  if v_guard_id is null then
    raise exception 'Approved guard record not found.';
  end if;

  select * into v_guard from public.guards where id = v_guard_id limit 1;

  select * into v_job
  from public.marketplace_jobs
  where id = p_job_id
    and assigned_guard_id = v_guard_id
  for update;

  if not found then
    raise exception 'This marketplace job is not assigned to you.';
  end if;

  if coalesce(v_job.current_status, '') not in ('guard_accepted','accepted','en_route','arrived','in_progress','active','proof_uploaded','completed') then
    raise exception 'Accept or start the marketplace job before uploading proof.';
  end if;

  if coalesce(p_bucket_id, '') <> 'patrol-proof' then
    raise exception 'Invalid proof storage bucket.';
  end if;

  if coalesce(p_object_path, '') = '' or p_object_path not like (p_job_id::text || '/%') then
    raise exception 'Invalid proof storage path.';
  end if;

  if not (v_kind like 'image/%' or v_kind like 'video/%') then
    raise exception 'Only photo or video proof files are allowed.';
  end if;

  insert into public.patrol_proof_items (
    id, request_id, marketplace_job_id, guard_id, bucket_id, object_path, file_name, file_type,
    file_size, public_url, note, report_selected, uploaded_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_job.patrol_request_id, p_job_id, v_guard_id, 'patrol-proof', p_object_path,
    coalesce(p_file_name, ''), coalesce(p_file_type, ''), coalesce(p_file_size, 0),
    coalesce(p_public_url, ''), coalesce(p_note, ''), false, now(), now(), now()
  )
  on conflict (bucket_id, object_path) do update
  set file_name = excluded.file_name,
      file_type = excluded.file_type,
      file_size = excluded.file_size,
      public_url = excluded.public_url,
      note = excluded.note,
      marketplace_job_id = excluded.marketplace_job_id,
      updated_at = now()
  returning * into v_proof;

  update public.marketplace_jobs
  set proof_count = greatest(coalesce(proof_count, 0), (select count(*) from public.patrol_proof_items where marketplace_job_id = p_job_id)),
      proof_uploaded_at = coalesce(proof_uploaded_at, now()),
      current_status = case when current_status <> 'completed' then 'proof_uploaded' else current_status end,
      updated_at = now()
  where id = p_job_id
  returning * into v_job;

  if v_job.patrol_request_id is not null then
    update public.patrol_requests
    set status = case when status <> 'completed' then 'in_progress' else status end,
        current_status = 'proof_uploaded',
        updated_at = now()
    where id = v_job.patrol_request_id;
  end if;

  insert into public.job_events (
    job_id, patrol_request_id, event_type, event_status,
    actor_agency_id, actor_guard_id, actor_role, actor_name,
    title, details, metadata, created_at
  ) values (
    p_job_id, v_job.patrol_request_id, 'proof_uploaded', 'proof_uploaded',
    v_job.accepted_agency_id, v_guard_id, 'guard', coalesce(v_guard.name, v_guard.email, 'Guard'),
    'Guard uploaded marketplace proof', coalesce(nullif(trim(p_note), ''), coalesce(p_file_name, 'Proof file uploaded')),
    jsonb_build_object('source','v4.0.11_guard_marketplace_job_flow','proof_id',v_proof.id,'file_name',p_file_name), now()
  );

  return jsonb_build_object('ok', true, 'proof', row_to_json(v_proof), 'job', row_to_json(v_job));
end;
$$;

grant execute on function public.cp_guard_update_marketplace_job_status(uuid, text) to authenticated;
grant execute on function public.cp_guard_register_marketplace_proof(uuid, text, text, text, text, bigint, text, text) to authenticated;

notify pgrst, 'reload schema';
