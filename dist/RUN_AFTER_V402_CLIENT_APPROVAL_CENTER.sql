-- Co Pilot Security Marketplace v4.0.2 — Client Approval Center SQL Patch
-- Run after RUN_AFTER_V401_AGENCY_JOB_BOARD.sql.
-- Adds platform-admin-safe client approval/rejection RPCs for the v4 marketplace client approval center.

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

  insert into public.clients (auth_user_id, email, name, phone, notes, status, created_at, updated_at)
  values (v_uid, lower(s.email), s.name, coalesce(s.phone, ''), coalesce(s.notes, ''), 'active', now(), now())
  on conflict (email) do update set
    auth_user_id = excluded.auth_user_id,
    name = excluded.name,
    phone = excluded.phone,
    notes = excluded.notes,
    status = 'active',
    updated_at = now()
  returning * into v_client;

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

  return jsonb_build_object('ok', true, 'client', row_to_json(v_client));
end;
$$;

create or replace function public.cp_reject_client_signup(p_signup_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.cp_is_platform_admin() then
    raise exception 'Only Platform Admin can reject clients.';
  end if;

  update public.pending_client_signups set
    status = 'rejected',
    reviewed_by = public.cp_current_uid(),
    reviewed_at = now(),
    updated_at = now()
  where id = p_signup_id;

  if not found then
    raise exception 'Client signup not found.';
  end if;

  return jsonb_build_object('ok', true, 'signup_id', p_signup_id, 'status', 'rejected');
end;
$$;

grant execute on function public.cp_approve_client_signup(uuid) to authenticated;
grant execute on function public.cp_reject_client_signup(uuid) to authenticated;

notify pgrst, 'reload schema';
