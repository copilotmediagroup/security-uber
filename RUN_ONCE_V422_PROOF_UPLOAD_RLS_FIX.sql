-- =====================================================================
-- RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql
-- Co Pilot Security Marketplace v4.0.22
-- Fixes marketplace proof uploads blocked by Supabase Storage RLS.
-- Run this ONCE in the marketplace Supabase SQL Editor when proof upload says:
-- "new row violates row-level security policy".
-- =====================================================================

create extension if not exists pgcrypto;

-- Keep the patrol-proof bucket public because the app stores public URLs for proof preview/report review.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'patrol-proof',
  'patrol-proof',
  true,
  104857600,
  array['image/jpeg','image/jpg','image/png','image/webp','image/gif','video/mp4','video/quicktime','video/webm']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- v4.0.22: Old policy only allowed storage paths that started with patrol_request_id.
-- Marketplace proof uploads use marketplace_job_id/object-name paths, so guards were blocked.
create or replace function public.cp_can_upload_patrol_proof_object(p_object_name text)
returns boolean
language plpgsql
security definer
set search_path = public, auth
stable
as $$
declare
  v_first text := split_part(coalesce(p_object_name, ''), '/', 1);
  v_row_id uuid;
  v_guard_id uuid := public.cp_current_guard_id();
begin
  if v_guard_id is null then
    return false;
  end if;

  if v_first !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;

  v_row_id := v_first::uuid;

  -- Legacy/single-company patrol request proof path: patrol_request_id/file
  if exists (
    select 1
    from public.patrol_requests r
    where r.id = v_row_id
      and r.guard_id = v_guard_id
      and coalesce(r.status, '') in ('accepted','in_progress','completed')
  ) then
    return true;
  end if;

  -- Marketplace proof path: marketplace_job_id/file
  if exists (
    select 1
    from public.marketplace_jobs j
    where j.id = v_row_id
      and j.assigned_guard_id = v_guard_id
      and coalesce(j.current_status, '') in (
        'guard_accepted','accepted','en_route','arrived','in_progress','active','proof_uploaded','completed'
      )
  ) then
    return true;
  end if;

  return false;
end;
$$;

create or replace function public.cp_can_read_patrol_proof_object(p_object_name text)
returns boolean
language plpgsql
security definer
set search_path = public, auth
stable
as $$
declare
  v_first text := split_part(coalesce(p_object_name, ''), '/', 1);
  v_row_id uuid;
  v_guard_id uuid := public.cp_current_guard_id();
  v_agency_id uuid := public.cp_current_agency_id();
begin
  if public.cp_is_platform_admin() then
    return true;
  end if;

  if v_first !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;

  v_row_id := v_first::uuid;

  -- Guard reads own legacy proof by patrol request folder.
  if v_guard_id is not null and exists (
    select 1
    from public.patrol_requests r
    where r.id = v_row_id
      and r.guard_id = v_guard_id
  ) then
    return true;
  end if;

  -- Guard reads own marketplace proof by marketplace job folder.
  if v_guard_id is not null and exists (
    select 1
    from public.marketplace_jobs j
    where j.id = v_row_id
      and j.assigned_guard_id = v_guard_id
  ) then
    return true;
  end if;

  -- Agency admin reads proof for jobs accepted by their agency.
  if v_agency_id is not null and exists (
    select 1
    from public.marketplace_jobs j
    where j.id = v_row_id
      and j.accepted_agency_id = v_agency_id
  ) then
    return true;
  end if;

  return false;
end;
$$;

-- Recreate storage object policies with marketplace-aware helper functions.
drop policy if exists "cp patrol proof guard upload" on storage.objects;
create policy "cp patrol proof guard upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'patrol-proof'
  and public.cp_can_upload_patrol_proof_object(name)
);

drop policy if exists "cp patrol proof admin guard read" on storage.objects;
create policy "cp patrol proof admin guard read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'patrol-proof'
  and public.cp_can_read_patrol_proof_object(name)
);

grant execute on function public.cp_can_upload_patrol_proof_object(text) to authenticated;
grant execute on function public.cp_can_read_patrol_proof_object(text) to authenticated;

notify pgrst, 'reload schema';

-- =====================================================================
-- END RUN_ONCE_V422_PROOF_UPLOAD_RLS_FIX.sql
-- =====================================================================
