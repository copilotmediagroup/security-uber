-- Co Pilot Security Patrol consolidated SQL handoff
-- Run only what has not already been run in Supabase.
-- If your database already has v1.3.0 + v1.3.4 + v1.3.5 installed, no SQL is required for v1.3.8.3.



-- ============================================================
-- v1.3.0 Clean Consolidated Baseline
-- Source: RUN_ONCE_V130_CLEAN_CONSOLIDATED_BASELINE.sql
-- ============================================================

-- v1.3.0 CLEAN CONSOLIDATED BASELINE
-- Run once in Supabase SQL Editor after uploading the v1.3.0 ZIP.
-- Purpose: one ordered baseline SQL so old SQL files do not overwrite newer RPC logic.
-- Keeps existing data. Uses CREATE IF NOT EXISTS / ALTER ADD COLUMN IF NOT EXISTS / CREATE OR REPLACE where possible.
-- No pricing. No SMS/email. No invite codes. No claim codes. No admin-created passwords.



-- ============================================================
-- Included from RUN_ONCE_V120_CLEAN_STABILIZED_CORE(1).sql
-- ============================================================

-- v1.2.0 CLEAN STABILIZED CORE
-- Run once in Supabase SQL Editor.
-- Clean flow: admin owner setup/login, guard/client self-signup, admin approval, property save.
-- No invite code. No claim code. No admin-created guard/client password. No Edge Function.

create extension if not exists pgcrypto;

create table if not exists public.business_settings (id uuid primary key default gen_random_uuid(), business_name text default 'Co Pilot Security', logo_url text default '', created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.profiles (id uuid primary key default gen_random_uuid(), auth_user_id uuid unique, email text unique, role text not null default 'client', display_name text default '', phone text default '', status text default 'active', client_id uuid, guard_id uuid, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.clients (id uuid primary key default gen_random_uuid(), auth_user_id uuid, email text unique, name text not null default 'Client', phone text default '', notes text default '', status text default 'active', created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.guards (id uuid primary key default gen_random_uuid(), auth_user_id uuid, email text unique, name text not null default 'Guard', phone text default '', vehicle text default '', license_plate text default '', work_card_number text default '', status text default 'active', availability_status text default 'offline', is_available boolean default false, current_lat double precision, current_lng double precision, last_seen_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.pending_guard_signups (id uuid primary key default gen_random_uuid(), auth_user_id uuid, name text not null, email text not null, phone text default '', vehicle text default '', license_plate text default '', work_card_number text default '', status text not null default 'pending', reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.pending_client_signups (id uuid primary key default gen_random_uuid(), auth_user_id uuid, name text not null, email text not null, phone text default '', notes text default '', status text not null default 'pending', reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists public.properties (id uuid primary key default gen_random_uuid(), client_id uuid references public.clients(id) on delete cascade, label text default 'Property', address text default '', address_line1 text default '', city text default '', state text default '', zip_code text default '', notes text default '', photo_url text default '', latitude double precision, longitude double precision, created_at timestamptz default now(), updated_at timestamptz default now());

create unique index if not exists pending_guard_signups_email_pending_idx on public.pending_guard_signups (lower(email)) where status = 'pending';
create unique index if not exists pending_client_signups_email_pending_idx on public.pending_client_signups (lower(email)) where status = 'pending';

create or replace function public.cp_current_uid() returns uuid language sql stable as $$ select nullif(coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''), ''), '')::uuid; $$;
create or replace function public.cp_current_email() returns text language sql stable as $$ select lower(coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''), '')); $$;
create or replace function public.cp_auth_user_id_for_email(p_email text) returns uuid language sql security definer set search_path = public, auth stable as $$ select id from auth.users where lower(email) = lower(trim(p_email)) order by created_at desc limit 1; $$;

create or replace function public.cp_is_admin() returns boolean language sql security definer set search_path = public, auth stable as $$ select exists (select 1 from public.profiles p where (p.auth_user_id = public.cp_current_uid() or p.id = public.cp_current_uid() or lower(coalesce(p.email, '')) = public.cp_current_email()) and p.role = 'admin' and coalesce(p.status, 'active') = 'active'); $$;

create or replace function public.cp_bootstrap_owner_admin(p_email text, p_display_name text default 'Owner Admin', p_business_name text default 'Co Pilot Security') returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid := coalesce(public.cp_current_uid(), public.cp_auth_user_id_for_email(p_email)); v_email text := lower(trim(p_email)); v_existing_email text; v_profile public.profiles%rowtype;
begin
  if v_uid is null then raise exception 'Auth user not found. Create the Supabase Auth account first.'; end if;
  select lower(email) into v_existing_email from public.profiles where role = 'admin' limit 1;
  if v_existing_email is not null and v_existing_email <> v_email then raise exception 'An owner admin already exists. Log in as that admin.'; end if;
  insert into public.profiles (id, auth_user_id, email, role, display_name, phone, status, created_at, updated_at) values (v_uid, v_uid, v_email, 'admin', coalesce(nullif(trim(p_display_name), ''), 'Owner Admin'), '', 'active', now(), now()) on conflict (id) do update set auth_user_id = excluded.auth_user_id, email = excluded.email, role = 'admin', display_name = excluded.display_name, status = 'active', updated_at = now() returning * into v_profile;
  insert into public.business_settings (business_name, logo_url, created_at, updated_at) values (coalesce(nullif(trim(p_business_name), ''), 'Co Pilot Security'), '', now(), now()) on conflict do nothing;
  update public.business_settings set business_name = coalesce(nullif(trim(p_business_name), ''), business_name), updated_at = now() where id = (select id from public.business_settings order by created_at asc limit 1);
  return jsonb_build_object('ok', true, 'profile', row_to_json(v_profile));
end; $$;

create or replace function public.cp_submit_guard_signup(p_auth_user_id uuid, p_name text, p_email text, p_phone text default '', p_vehicle text default '', p_license_plate text default '', p_work_card_number text default '') returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare v_email text := lower(trim(p_email)); v_uid uuid := coalesce(p_auth_user_id, public.cp_auth_user_id_for_email(p_email)); v_id uuid;
begin
  if v_email = '' then raise exception 'Guard email is required.'; end if; if trim(coalesce(p_name, '')) = '' then raise exception 'Guard name is required.'; end if;
  select id into v_id from public.pending_guard_signups where lower(email)=v_email and status='pending' limit 1;
  if v_id is null then insert into public.pending_guard_signups (auth_user_id, name, email, phone, vehicle, license_plate, work_card_number, status, created_at, updated_at) values (v_uid, trim(p_name), v_email, coalesce(p_phone,''), coalesce(p_vehicle,''), coalesce(p_license_plate,''), coalesce(p_work_card_number,''), 'pending', now(), now()) returning id into v_id;
  else update public.pending_guard_signups set auth_user_id = coalesce(v_uid, auth_user_id), name=trim(p_name), phone=coalesce(p_phone,''), vehicle=coalesce(p_vehicle,''), license_plate=coalesce(p_license_plate,''), work_card_number=coalesce(p_work_card_number,''), updated_at=now() where id=v_id; end if;
  return jsonb_build_object('ok', true, 'signup_id', v_id, 'status', 'pending', 'email', v_email);
end; $$;

create or replace function public.cp_submit_client_signup(p_auth_user_id uuid, p_name text, p_email text, p_phone text default '', p_notes text default '') returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare v_email text := lower(trim(p_email)); v_uid uuid := coalesce(p_auth_user_id, public.cp_auth_user_id_for_email(p_email)); v_id uuid;
begin
  if v_email = '' then raise exception 'Client email is required.'; end if; if trim(coalesce(p_name, '')) = '' then raise exception 'Client name is required.'; end if;
  select id into v_id from public.pending_client_signups where lower(email)=v_email and status='pending' limit 1;
  if v_id is null then insert into public.pending_client_signups (auth_user_id, name, email, phone, notes, status, created_at, updated_at) values (v_uid, trim(p_name), v_email, coalesce(p_phone,''), coalesce(p_notes,''), 'pending', now(), now()) returning id into v_id;
  else update public.pending_client_signups set auth_user_id = coalesce(v_uid, auth_user_id), name=trim(p_name), phone=coalesce(p_phone,''), notes=coalesce(p_notes,''), updated_at=now() where id=v_id; end if;
  return jsonb_build_object('ok', true, 'signup_id', v_id, 'status', 'pending', 'email', v_email);
end; $$;

create or replace function public.cp_approve_guard_signup(p_signup_id uuid) returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare s record; v_uid uuid; v_guard public.guards%rowtype;
begin
  if not public.cp_is_admin() then raise exception 'Only admin can approve guards.'; end if;
  select * into s from public.pending_guard_signups where id=p_signup_id limit 1; if not found then raise exception 'Guard signup not found.'; end if;
  v_uid := coalesce(s.auth_user_id, public.cp_auth_user_id_for_email(s.email)); if v_uid is null then raise exception 'No Supabase Auth user exists for this guard email.'; end if;
  insert into public.guards (auth_user_id,email,name,phone,vehicle,license_plate,work_card_number,status,availability_status,is_available,created_at,updated_at) values (v_uid,lower(s.email),s.name,coalesce(s.phone,''),coalesce(s.vehicle,''),coalesce(s.license_plate,''),coalesce(s.work_card_number,''),'active','offline',false,now(),now()) on conflict (email) do update set auth_user_id=excluded.auth_user_id,name=excluded.name,phone=excluded.phone,vehicle=excluded.vehicle,license_plate=excluded.license_plate,work_card_number=excluded.work_card_number,status='active',updated_at=now() returning * into v_guard;
  insert into public.profiles (id,auth_user_id,email,role,display_name,phone,status,guard_id,created_at,updated_at) values (v_uid,v_uid,lower(s.email),'guard',s.name,coalesce(s.phone,''),'active',v_guard.id,now(),now()) on conflict (id) do update set auth_user_id=excluded.auth_user_id,email=excluded.email,role='guard',display_name=excluded.display_name,phone=excluded.phone,status='active',guard_id=excluded.guard_id,updated_at=now();
  update public.pending_guard_signups set status='approved', reviewed_by=public.cp_current_uid(), reviewed_at=now(), updated_at=now() where id=p_signup_id;
  return jsonb_build_object('ok', true, 'guard', row_to_json(v_guard));
end; $$;

create or replace function public.cp_approve_client_signup(p_signup_id uuid) returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare s record; v_uid uuid; v_client public.clients%rowtype;
begin
  if not public.cp_is_admin() then raise exception 'Only admin can approve clients.'; end if;
  select * into s from public.pending_client_signups where id=p_signup_id limit 1; if not found then raise exception 'Client signup not found.'; end if;
  v_uid := coalesce(s.auth_user_id, public.cp_auth_user_id_for_email(s.email)); if v_uid is null then raise exception 'No Supabase Auth user exists for this client email.'; end if;
  insert into public.clients (auth_user_id,email,name,phone,notes,status,created_at,updated_at) values (v_uid,lower(s.email),s.name,coalesce(s.phone,''),coalesce(s.notes,''),'active',now(),now()) on conflict (email) do update set auth_user_id=excluded.auth_user_id,name=excluded.name,phone=excluded.phone,notes=excluded.notes,status='active',updated_at=now() returning * into v_client;
  insert into public.profiles (id,auth_user_id,email,role,display_name,phone,status,client_id,created_at,updated_at) values (v_uid,v_uid,lower(s.email),'client',s.name,coalesce(s.phone,''),'active',v_client.id,now(),now()) on conflict (id) do update set auth_user_id=excluded.auth_user_id,email=excluded.email,role='client',display_name=excluded.display_name,phone=excluded.phone,status='active',client_id=excluded.client_id,updated_at=now();
  update public.pending_client_signups set status='approved', reviewed_by=public.cp_current_uid(), reviewed_at=now(), updated_at=now() where id=p_signup_id;
  return jsonb_build_object('ok', true, 'client', row_to_json(v_client));
end; $$;

create or replace function public.cp_reject_guard_signup(p_signup_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$ begin if not public.cp_is_admin() then raise exception 'Only admin can reject guards.'; end if; update public.pending_guard_signups set status='rejected', reviewed_by=public.cp_current_uid(), reviewed_at=now(), updated_at=now() where id=p_signup_id; return jsonb_build_object('ok', true); end; $$;
create or replace function public.cp_reject_client_signup(p_signup_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$ begin if not public.cp_is_admin() then raise exception 'Only admin can reject clients.'; end if; update public.pending_client_signups set status='rejected', reviewed_by=public.cp_current_uid(), reviewed_at=now(), updated_at=now() where id=p_signup_id; return jsonb_build_object('ok', true); end; $$;

create or replace function public.cp_save_property_for_client(p_property_id uuid default null, p_client_id uuid default null, p_label text default 'Property', p_address text default '', p_city text default '', p_state text default '', p_zip_code text default '', p_photo_url text default '', p_notes text default '', p_latitude double precision default null, p_longitude double precision default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := public.cp_current_uid(); v_email text := public.cp_current_email(); v_is_admin boolean := public.cp_is_admin(); v_client public.clients%rowtype; v_property public.properties%rowtype;
begin
  if coalesce(trim(p_address),'')='' then raise exception 'Property address is required.'; end if; if coalesce(trim(p_zip_code),'')='' then raise exception 'Property zip code is required.'; end if;
  if p_client_id is null then select * into v_client from public.clients where auth_user_id=v_uid or lower(email)=v_email limit 1; else select * into v_client from public.clients where id=p_client_id limit 1; end if;
  if not found then raise exception 'Approved client record not found.'; end if;
  if not v_is_admin and not (v_client.auth_user_id=v_uid or lower(v_client.email)=v_email) then raise exception 'You can only save your own property.'; end if;
  if p_property_id is not null and exists(select 1 from public.properties where id=p_property_id) then update public.properties set client_id=v_client.id,label=coalesce(nullif(trim(p_label),''),'Property'),address=p_address,address_line1=p_address,city=p_city,state=p_state,zip_code=p_zip_code,photo_url=coalesce(p_photo_url,''),notes=coalesce(p_notes,''),latitude=p_latitude,longitude=p_longitude,updated_at=now() where id=p_property_id returning * into v_property;
  else insert into public.properties (client_id,label,address,address_line1,city,state,zip_code,photo_url,notes,latitude,longitude,created_at,updated_at) values (v_client.id,coalesce(nullif(trim(p_label),''),'Property'),p_address,p_address,p_city,p_state,p_zip_code,coalesce(p_photo_url,''),coalesce(p_notes,''),p_latitude,p_longitude,now(),now()) returning * into v_property; end if;
  return jsonb_build_object('ok', true, 'property', row_to_json(v_property));
end; $$;

create or replace function public.cp_update_guard_status_location(p_availability_status text default null, p_lat double precision default null, p_lng double precision default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := public.cp_current_uid(); v_email text := public.cp_current_email(); v_guard public.guards%rowtype; v_status text := lower(coalesce(nullif(trim(p_availability_status),''),'offline'));
begin
  select * into v_guard from public.guards where auth_user_id=v_uid or lower(email)=v_email limit 1; if not found then raise exception 'Approved guard record not found.'; end if;
  if v_status not in ('online','offline') then v_status := coalesce(nullif(v_guard.availability_status,''),'offline'); end if;
  update public.guards set availability_status=v_status,is_available=(v_status='online'),current_lat=coalesce(p_lat,current_lat),current_lng=coalesce(p_lng,current_lng),last_seen_at=now(),updated_at=now() where id=v_guard.id returning * into v_guard;
  return jsonb_build_object('ok', true, 'guard', row_to_json(v_guard));
end; $$;

create or replace function public.cp_get_app_data() returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := public.cp_current_uid(); v_email text := public.cp_current_email(); v_profile public.profiles%rowtype; v_role text; v_client_id uuid; v_guard_id uuid;
begin
  select * into v_profile from public.profiles where auth_user_id=v_uid or id=v_uid or lower(email)=v_email limit 1;
  if not found then return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.'); end if;
  v_role := v_profile.role; v_client_id := v_profile.client_id; v_guard_id := v_profile.guard_id;
  if v_role='admin' then return jsonb_build_object('ok',true,'profile',row_to_json(v_profile),'settings',coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s),'[]'::jsonb),'clients',coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c),'[]'::jsonb),'guards',coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g),'[]'::jsonb),'guardSignups',coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s),'[]'::jsonb),'clientSignups',coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s),'[]'::jsonb),'properties',coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p),'[]'::jsonb));
  elsif v_role='client' then return jsonb_build_object('ok',true,'profile',row_to_json(v_profile),'settings',coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s),'[]'::jsonb),'clients',coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id=v_client_id or c.auth_user_id=v_uid or lower(c.email)=v_email),'[]'::jsonb),'guards','[]'::jsonb,'guardSignups','[]'::jsonb,'clientSignups','[]'::jsonb,'properties',coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id=v_client_id),'[]'::jsonb));
  elsif v_role='guard' then return jsonb_build_object('ok',true,'profile',row_to_json(v_profile),'settings',coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s),'[]'::jsonb),'clients','[]'::jsonb,'guards',coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id=v_guard_id or g.auth_user_id=v_uid or lower(g.email)=v_email),'[]'::jsonb),'guardSignups','[]'::jsonb,'clientSignups','[]'::jsonb,'properties','[]'::jsonb);
  else return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.'); end if;
end; $$;

create or replace function public.cp_admin_delete_guard(p_guard_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$ begin if not public.cp_is_admin() then raise exception 'Only admin can delete guards.'; end if; delete from public.profiles where guard_id=p_guard_id; delete from public.guards where id=p_guard_id; return jsonb_build_object('ok', true); end; $$;
create or replace function public.cp_admin_delete_client(p_client_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$ begin if not public.cp_is_admin() then raise exception 'Only admin can delete clients.'; end if; delete from public.profiles where client_id=p_client_id; delete from public.clients where id=p_client_id; return jsonb_build_object('ok', true); end; $$;
create or replace function public.cp_admin_delete_property(p_property_id uuid) returns jsonb language plpgsql security definer set search_path = public as $$ begin if not public.cp_is_admin() then raise exception 'Only admin can delete properties.'; end if; delete from public.properties where id=p_property_id; return jsonb_build_object('ok', true); end; $$;

alter table public.business_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.guards enable row level security;
alter table public.pending_guard_signups enable row level security;
alter table public.pending_client_signups enable row level security;
alter table public.properties enable row level security;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_bootstrap_owner_admin(text,text,text) to authenticated;
grant execute on function public.cp_submit_guard_signup(uuid,text,text,text,text,text,text) to anon, authenticated;
grant execute on function public.cp_submit_client_signup(uuid,text,text,text,text) to anon, authenticated;
grant execute on function public.cp_approve_guard_signup(uuid) to authenticated;
grant execute on function public.cp_approve_client_signup(uuid) to authenticated;
grant execute on function public.cp_reject_guard_signup(uuid) to authenticated;
grant execute on function public.cp_reject_client_signup(uuid) to authenticated;
grant execute on function public.cp_save_property_for_client(uuid,uuid,text,text,text,text,text,text,text,double precision,double precision) to authenticated;
grant execute on function public.cp_update_guard_status_location(text,double precision,double precision) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;
grant execute on function public.cp_admin_delete_guard(uuid) to authenticated;
grant execute on function public.cp_admin_delete_client(uuid) to authenticated;
grant execute on function public.cp_admin_delete_property(uuid) to authenticated;

notify pgrst, 'reload schema';

-- v1.2.0 compatibility hardening for existing projects/tables
alter table public.business_settings add column if not exists business_name text default 'Co Pilot Security';
alter table public.business_settings add column if not exists logo_url text default '';
alter table public.business_settings add column if not exists created_at timestamptz default now();
alter table public.business_settings add column if not exists updated_at timestamptz default now();
alter table public.business_settings alter column id set default gen_random_uuid();

alter table public.profiles add column if not exists auth_user_id uuid;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists role text;
alter table public.profiles add column if not exists display_name text default '';
alter table public.profiles add column if not exists phone text default '';
alter table public.profiles add column if not exists status text default 'active';
alter table public.profiles add column if not exists client_id uuid;
alter table public.profiles add column if not exists guard_id uuid;
alter table public.profiles add column if not exists created_at timestamptz default now();
alter table public.profiles add column if not exists updated_at timestamptz default now();
alter table public.profiles alter column id set default gen_random_uuid();

alter table public.clients add column if not exists auth_user_id uuid;
alter table public.clients add column if not exists email text;
alter table public.clients add column if not exists name text default 'Client';
alter table public.clients add column if not exists phone text default '';
alter table public.clients add column if not exists notes text default '';
alter table public.clients add column if not exists status text default 'active';
alter table public.clients add column if not exists created_at timestamptz default now();
alter table public.clients add column if not exists updated_at timestamptz default now();
alter table public.clients alter column id set default gen_random_uuid();

alter table public.guards add column if not exists auth_user_id uuid;
alter table public.guards add column if not exists email text;
alter table public.guards add column if not exists name text default 'Guard';
alter table public.guards add column if not exists phone text default '';
alter table public.guards add column if not exists vehicle text default '';
alter table public.guards add column if not exists license_plate text default '';
alter table public.guards add column if not exists work_card_number text default '';
alter table public.guards add column if not exists status text default 'active';
alter table public.guards add column if not exists availability_status text default 'offline';
alter table public.guards add column if not exists is_available boolean default false;
alter table public.guards add column if not exists current_lat double precision;
alter table public.guards add column if not exists current_lng double precision;
alter table public.guards add column if not exists last_seen_at timestamptz;
alter table public.guards add column if not exists created_at timestamptz default now();
alter table public.guards add column if not exists updated_at timestamptz default now();
alter table public.guards alter column id set default gen_random_uuid();

alter table public.properties add column if not exists client_id uuid;
alter table public.properties add column if not exists label text default 'Property';
alter table public.properties add column if not exists address text default '';
alter table public.properties add column if not exists address_line1 text default '';
alter table public.properties add column if not exists city text default '';
alter table public.properties add column if not exists state text default '';
alter table public.properties add column if not exists zip_code text default '';
alter table public.properties add column if not exists notes text default '';
alter table public.properties add column if not exists photo_url text default '';
alter table public.properties add column if not exists latitude double precision;
alter table public.properties add column if not exists longitude double precision;
alter table public.properties add column if not exists created_at timestamptz default now();
alter table public.properties add column if not exists updated_at timestamptz default now();
alter table public.properties alter column id set default gen_random_uuid();

create or replace function public.cp_bootstrap_owner_admin(p_email text, p_display_name text default 'Owner Admin', p_business_name text default 'Co Pilot Security')
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  v_uid uuid := coalesce(public.cp_current_uid(), public.cp_auth_user_id_for_email(p_email));
  v_email text := lower(trim(p_email));
  v_existing_admin_email text;
  v_profile_id uuid;
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then raise exception 'Auth user not found. Create the Supabase Auth account first.'; end if;
  select lower(email) into v_existing_admin_email from public.profiles where role::text = 'admin' limit 1;
  if v_existing_admin_email is not null and v_existing_admin_email <> v_email then raise exception 'An owner admin already exists. Log in as that admin.'; end if;
  select id into v_profile_id from public.profiles where id = v_uid or lower(coalesce(email,'')) = v_email limit 1;
  if v_profile_id is null then
    insert into public.profiles (id, auth_user_id, email, role, display_name, phone, status, created_at, updated_at)
    values (v_uid, v_uid, v_email, 'admin', coalesce(nullif(trim(p_display_name), ''), 'Owner Admin'), '', 'active', now(), now()) returning * into v_profile;
  else
    update public.profiles set auth_user_id=v_uid, email=v_email, role='admin', display_name=coalesce(nullif(trim(p_display_name), ''), 'Owner Admin'), status='active', updated_at=now() where id=v_profile_id returning * into v_profile;
  end if;
  insert into public.business_settings (business_name, logo_url, created_at, updated_at) select coalesce(nullif(trim(p_business_name), ''), 'Co Pilot Security'), '', now(), now() where not exists (select 1 from public.business_settings);
  update public.business_settings set business_name=coalesce(nullif(trim(p_business_name), ''), business_name), updated_at=now() where id=(select id from public.business_settings order by created_at asc limit 1);
  return jsonb_build_object('ok', true, 'profile', row_to_json(v_profile));
end;
$$;

create or replace function public.cp_approve_guard_signup(p_signup_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  s record; v_uid uuid; v_guard_id uuid; v_profile_id uuid; v_guard public.guards%rowtype;
begin
  if not public.cp_is_admin() then raise exception 'Only admin can approve guards.'; end if;
  select * into s from public.pending_guard_signups where id=p_signup_id limit 1; if not found then raise exception 'Guard signup not found.'; end if;
  v_uid := coalesce(s.auth_user_id, public.cp_auth_user_id_for_email(s.email)); if v_uid is null then raise exception 'No Supabase Auth user exists for this guard email.'; end if;
  select id into v_guard_id from public.guards where lower(coalesce(email,'')) = lower(s.email) limit 1;
  if v_guard_id is null then
    insert into public.guards (auth_user_id,email,name,phone,vehicle,license_plate,work_card_number,status,availability_status,is_available,created_at,updated_at)
    values (v_uid,lower(s.email),s.name,coalesce(s.phone,''),coalesce(s.vehicle,''),coalesce(s.license_plate,''),coalesce(s.work_card_number,''),'active','offline',false,now(),now()) returning * into v_guard;
  else
    update public.guards set auth_user_id=v_uid,email=lower(s.email),name=s.name,phone=coalesce(s.phone,''),vehicle=coalesce(s.vehicle,''),license_plate=coalesce(s.license_plate,''),work_card_number=coalesce(s.work_card_number,''),status='active',updated_at=now() where id=v_guard_id returning * into v_guard;
  end if;
  select id into v_profile_id from public.profiles where id=v_uid or lower(coalesce(email,''))=lower(s.email) limit 1;
  if v_profile_id is null then
    insert into public.profiles (id,auth_user_id,email,role,display_name,phone,status,guard_id,created_at,updated_at) values (v_uid,v_uid,lower(s.email),'guard',s.name,coalesce(s.phone,''),'active',v_guard.id,now(),now());
  else
    update public.profiles set auth_user_id=v_uid,email=lower(s.email),role='guard',display_name=s.name,phone=coalesce(s.phone,''),status='active',guard_id=v_guard.id,updated_at=now() where id=v_profile_id;
  end if;
  update public.pending_guard_signups set status='approved', reviewed_by=public.cp_current_uid(), reviewed_at=now(), updated_at=now() where id=p_signup_id;
  return jsonb_build_object('ok', true, 'guard', row_to_json(v_guard));
end;
$$;

create or replace function public.cp_approve_client_signup(p_signup_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  s record; v_uid uuid; v_client_id uuid; v_profile_id uuid; v_client public.clients%rowtype;
begin
  if not public.cp_is_admin() then raise exception 'Only admin can approve clients.'; end if;
  select * into s from public.pending_client_signups where id=p_signup_id limit 1; if not found then raise exception 'Client signup not found.'; end if;
  v_uid := coalesce(s.auth_user_id, public.cp_auth_user_id_for_email(s.email)); if v_uid is null then raise exception 'No Supabase Auth user exists for this client email.'; end if;
  select id into v_client_id from public.clients where lower(coalesce(email,'')) = lower(s.email) limit 1;
  if v_client_id is null then
    insert into public.clients (auth_user_id,email,name,phone,notes,status,created_at,updated_at) values (v_uid,lower(s.email),s.name,coalesce(s.phone,''),coalesce(s.notes,''),'active',now(),now()) returning * into v_client;
  else
    update public.clients set auth_user_id=v_uid,email=lower(s.email),name=s.name,phone=coalesce(s.phone,''),notes=coalesce(s.notes,''),status='active',updated_at=now() where id=v_client_id returning * into v_client;
  end if;
  select id into v_profile_id from public.profiles where id=v_uid or lower(coalesce(email,''))=lower(s.email) limit 1;
  if v_profile_id is null then
    insert into public.profiles (id,auth_user_id,email,role,display_name,phone,status,client_id,created_at,updated_at) values (v_uid,v_uid,lower(s.email),'client',s.name,coalesce(s.phone,''),'active',v_client.id,now(),now());
  else
    update public.profiles set auth_user_id=v_uid,email=lower(s.email),role='client',display_name=s.name,phone=coalesce(s.phone,''),status='active',client_id=v_client.id,updated_at=now() where id=v_profile_id;
  end if;
  update public.pending_client_signups set status='approved', reviewed_by=public.cp_current_uid(), reviewed_at=now(), updated_at=now() where id=p_signup_id;
  return jsonb_build_object('ok', true, 'client', row_to_json(v_client));
end;
$$;

notify pgrst, 'reload schema';


-- v1.2.1 overload-safe property save function
-- v1.2.1 PROPERTY RPC OVERLOAD FIX
-- Run this once in Supabase SQL Editor.
--
-- Problem fixed:
-- Older builds left multiple overloaded cp_save_property_for_client() functions in Supabase.
-- PostgREST cannot choose between overloaded RPC functions when parameters overlap.
--
-- Fix:
-- This creates a new uniquely named function:
-- public.cp_core_save_property()
--
-- The v1.2.1 app calls only this unique function.
-- No invite code. No claim code. No admin-created guard/client passwords.

create extension if not exists pgcrypto;

-- Optional cleanup: remove older ambiguous property RPC overloads if they exist.
drop function if exists public.cp_save_property_for_client(
  uuid, uuid, text, text, text, text, text, text, text, double precision, double precision
);

drop function if exists public.cp_save_property_for_client(
  uuid, uuid, text, text, text, text, text, text, text, text, double precision, double precision
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid,
  email text unique,
  name text not null default 'Client',
  phone text default '',
  notes text default '',
  status text default 'active',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  label text default 'Property',
  address text default '',
  address_line1 text default '',
  city text default '',
  state text default '',
  zip_code text default '',
  notes text default '',
  photo_url text default '',
  latitude double precision,
  longitude double precision,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.properties add column if not exists client_id uuid;
alter table public.properties add column if not exists label text;
alter table public.properties add column if not exists address text;
alter table public.properties add column if not exists address_line1 text;
alter table public.properties add column if not exists city text;
alter table public.properties add column if not exists state text;
alter table public.properties add column if not exists zip_code text;
alter table public.properties add column if not exists notes text;
alter table public.properties add column if not exists photo_url text;
alter table public.properties add column if not exists latitude double precision;
alter table public.properties add column if not exists longitude double precision;
alter table public.properties add column if not exists created_at timestamptz default now();
alter table public.properties add column if not exists updated_at timestamptz default now();

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

create or replace function public.cp_is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (
      p.auth_user_id = public.cp_current_uid()
      or p.id = public.cp_current_uid()
      or lower(coalesce(p.email, '')) = public.cp_current_email()
    )
    and p.role = 'admin'
    and coalesce(p.status, 'active') = 'active'
  );
$$;

create or replace function public.cp_core_save_property(
  p_property_id uuid default null,
  p_client_id uuid default null,
  p_label text default 'Property',
  p_address text default '',
  p_city text default '',
  p_state text default '',
  p_zip_code text default '',
  p_photo_url text default '',
  p_notes text default '',
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_is_admin boolean := public.cp_is_admin();
  v_client public.clients%rowtype;
  v_property public.properties%rowtype;
begin
  if coalesce(trim(p_address), '') = '' then
    raise exception 'Property address is required.';
  end if;

  if coalesce(trim(p_zip_code), '') = '' then
    raise exception 'Property zip code is required.';
  end if;

  if p_client_id is null then
    select * into v_client
    from public.clients
    where auth_user_id = v_uid or lower(email) = v_email
    limit 1;
  else
    select * into v_client
    from public.clients
    where id = p_client_id
    limit 1;
  end if;

  if not found then
    raise exception 'Approved client record not found.';
  end if;

  if not v_is_admin then
    if not (v_client.auth_user_id = v_uid or lower(v_client.email) = v_email) then
      raise exception 'You can only save your own property.';
    end if;
  end if;

  if p_property_id is not null and exists(select 1 from public.properties where id = p_property_id) then
    update public.properties
    set client_id = v_client.id,
        label = coalesce(nullif(trim(p_label), ''), 'Property'),
        address = p_address,
        address_line1 = p_address,
        city = p_city,
        state = p_state,
        zip_code = p_zip_code,
        photo_url = coalesce(p_photo_url, ''),
        notes = coalesce(p_notes, ''),
        latitude = p_latitude,
        longitude = p_longitude,
        updated_at = now()
    where id = p_property_id
    returning * into v_property;
  else
    insert into public.properties (
      id, client_id, label, address, address_line1, city, state, zip_code,
      photo_url, notes, latitude, longitude, created_at, updated_at
    )
    values (
      gen_random_uuid(), v_client.id, coalesce(nullif(trim(p_label), ''), 'Property'),
      p_address, p_address, p_city, p_state, p_zip_code,
      coalesce(p_photo_url, ''), coalesce(p_notes, ''),
      p_latitude, p_longitude, now(), now()
    )
    returning * into v_property;
  end if;

  return jsonb_build_object('ok', true, 'property', row_to_json(v_property));
end;
$$;

grant execute on function public.cp_core_save_property(
  uuid, uuid, text, text, text, text, text, text, text, double precision, double precision
) to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V121_PROPERTY_RPC_OVERLOAD_FIX(1).sql
-- ============================================================

-- v1.2.1 PROPERTY RPC OVERLOAD FIX
-- Run this once in Supabase SQL Editor.
--
-- Problem fixed:
-- Older builds left multiple overloaded cp_save_property_for_client() functions in Supabase.
-- PostgREST cannot choose between overloaded RPC functions when parameters overlap.
--
-- Fix:
-- This creates a new uniquely named function:
-- public.cp_core_save_property()
--
-- The v1.2.1 app calls only this unique function.
-- No invite code. No claim code. No admin-created guard/client passwords.

create extension if not exists pgcrypto;

-- Optional cleanup: remove older ambiguous property RPC overloads if they exist.
drop function if exists public.cp_save_property_for_client(
  uuid, uuid, text, text, text, text, text, text, text, double precision, double precision
);

drop function if exists public.cp_save_property_for_client(
  uuid, uuid, text, text, text, text, text, text, text, text, double precision, double precision
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid,
  email text unique,
  name text not null default 'Client',
  phone text default '',
  notes text default '',
  status text default 'active',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  label text default 'Property',
  address text default '',
  address_line1 text default '',
  city text default '',
  state text default '',
  zip_code text default '',
  notes text default '',
  photo_url text default '',
  latitude double precision,
  longitude double precision,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.properties add column if not exists client_id uuid;
alter table public.properties add column if not exists label text;
alter table public.properties add column if not exists address text;
alter table public.properties add column if not exists address_line1 text;
alter table public.properties add column if not exists city text;
alter table public.properties add column if not exists state text;
alter table public.properties add column if not exists zip_code text;
alter table public.properties add column if not exists notes text;
alter table public.properties add column if not exists photo_url text;
alter table public.properties add column if not exists latitude double precision;
alter table public.properties add column if not exists longitude double precision;
alter table public.properties add column if not exists created_at timestamptz default now();
alter table public.properties add column if not exists updated_at timestamptz default now();

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

create or replace function public.cp_is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (
      p.auth_user_id = public.cp_current_uid()
      or p.id = public.cp_current_uid()
      or lower(coalesce(p.email, '')) = public.cp_current_email()
    )
    and p.role = 'admin'
    and coalesce(p.status, 'active') = 'active'
  );
$$;

create or replace function public.cp_core_save_property(
  p_property_id uuid default null,
  p_client_id uuid default null,
  p_label text default 'Property',
  p_address text default '',
  p_city text default '',
  p_state text default '',
  p_zip_code text default '',
  p_photo_url text default '',
  p_notes text default '',
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_is_admin boolean := public.cp_is_admin();
  v_client public.clients%rowtype;
  v_property public.properties%rowtype;
begin
  if coalesce(trim(p_address), '') = '' then
    raise exception 'Property address is required.';
  end if;

  if coalesce(trim(p_zip_code), '') = '' then
    raise exception 'Property zip code is required.';
  end if;

  if p_client_id is null then
    select * into v_client
    from public.clients
    where auth_user_id = v_uid or lower(email) = v_email
    limit 1;
  else
    select * into v_client
    from public.clients
    where id = p_client_id
    limit 1;
  end if;

  if not found then
    raise exception 'Approved client record not found.';
  end if;

  if not v_is_admin then
    if not (v_client.auth_user_id = v_uid or lower(v_client.email) = v_email) then
      raise exception 'You can only save your own property.';
    end if;
  end if;

  if p_property_id is not null and exists(select 1 from public.properties where id = p_property_id) then
    update public.properties
    set client_id = v_client.id,
        label = coalesce(nullif(trim(p_label), ''), 'Property'),
        address = p_address,
        address_line1 = p_address,
        city = p_city,
        state = p_state,
        zip_code = p_zip_code,
        photo_url = coalesce(p_photo_url, ''),
        notes = coalesce(p_notes, ''),
        latitude = p_latitude,
        longitude = p_longitude,
        updated_at = now()
    where id = p_property_id
    returning * into v_property;
  else
    insert into public.properties (
      id, client_id, label, address, address_line1, city, state, zip_code,
      photo_url, notes, latitude, longitude, created_at, updated_at
    )
    values (
      gen_random_uuid(), v_client.id, coalesce(nullif(trim(p_label), ''), 'Property'),
      p_address, p_address, p_city, p_state, p_zip_code,
      coalesce(p_photo_url, ''), coalesce(p_notes, ''),
      p_latitude, p_longitude, now(), now()
    )
    returning * into v_property;
  end if;

  return jsonb_build_object('ok', true, 'property', row_to_json(v_property));
end;
$$;

grant execute on function public.cp_core_save_property(
  uuid, uuid, text, text, text, text, text, text, text, double precision, double precision
) to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V123_REQUEST_DISPATCH_CORE.sql
-- ============================================================

-- v1.2.3 REQUEST / DISPATCH CORE
-- Run once in Supabase SQL Editor after the confirmed v1.2.1 property RPC fix is installed.
-- Adds only the confirmed next workflow:
-- 1) Client submits patrol request from saved property.
-- 2) Admin sees Pending Dispatch.
-- 3) Admin assigns an approved guard.
-- 4) Guard sees assigned request.
-- No invite code. No claim code. No admin-created guard/client passwords.
-- No Edge Functions. No proof upload. No final reports. No live ETA.

create extension if not exists pgcrypto;

create table if not exists public.patrol_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  property_id uuid references public.properties(id) on delete set null,
  guard_id uuid references public.guards(id) on delete set null,
  status text not null default 'pending_dispatch',
  priority text not null default 'normal',
  instructions text default '',
  requested_at timestamptz default now(),
  assigned_by uuid,
  assigned_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.patrol_requests add column if not exists client_id uuid;
alter table public.patrol_requests add column if not exists property_id uuid;
alter table public.patrol_requests add column if not exists guard_id uuid;
alter table public.patrol_requests add column if not exists status text default 'pending_dispatch';
alter table public.patrol_requests add column if not exists priority text default 'normal';
alter table public.patrol_requests add column if not exists instructions text default '';
alter table public.patrol_requests add column if not exists requested_at timestamptz default now();
alter table public.patrol_requests add column if not exists assigned_by uuid;
alter table public.patrol_requests add column if not exists assigned_at timestamptz;
alter table public.patrol_requests add column if not exists created_at timestamptz default now();
alter table public.patrol_requests add column if not exists updated_at timestamptz default now();

create index if not exists patrol_requests_client_id_idx on public.patrol_requests(client_id);
create index if not exists patrol_requests_property_id_idx on public.patrol_requests(property_id);
create index if not exists patrol_requests_guard_id_idx on public.patrol_requests(guard_id);
create index if not exists patrol_requests_status_idx on public.patrol_requests(status);
create index if not exists patrol_requests_created_at_idx on public.patrol_requests(created_at desc);

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

create or replace function public.cp_is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (
      p.auth_user_id = public.cp_current_uid()
      or p.id = public.cp_current_uid()
      or lower(coalesce(p.email, '')) = public.cp_current_email()
    )
    and p.role = 'admin'
    and coalesce(p.status, 'active') = 'active'
  );
$$;

create or replace function public.cp_submit_patrol_request(
  p_property_id uuid,
  p_priority text default 'normal',
  p_instructions text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_client public.clients%rowtype;
  v_property public.properties%rowtype;
  v_request public.patrol_requests%rowtype;
  v_priority text := lower(coalesce(nullif(trim(p_priority), ''), 'normal'));
begin
  if p_property_id is null then
    raise exception 'Select a saved property before requesting patrol.';
  end if;

  select * into v_client
  from public.clients
  where auth_user_id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    raise exception 'Approved client record not found.';
  end if;

  select * into v_property
  from public.properties
  where id = p_property_id and client_id = v_client.id
  limit 1;

  if not found then
    raise exception 'You can only request patrol for your own saved property.';
  end if;

  if v_priority not in ('normal', 'high', 'urgent') then
    v_priority := 'normal';
  end if;

  insert into public.patrol_requests (
    id, client_id, property_id, guard_id, status, priority, instructions,
    requested_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_client.id, v_property.id, null, 'pending_dispatch', v_priority,
    coalesce(p_instructions, ''), now(), now(), now()
  ) returning * into v_request;

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request));
end;
$$;

create or replace function public.cp_admin_assign_patrol_request(
  p_request_id uuid,
  p_guard_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.patrol_requests%rowtype;
  v_guard public.guards%rowtype;
begin
  if not public.cp_is_admin() then
    raise exception 'Only admin can dispatch patrol requests.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
  limit 1;

  if not found then
    raise exception 'Patrol request not found.';
  end if;

  select * into v_guard
  from public.guards
  where id = p_guard_id and coalesce(status, 'active') = 'active'
  limit 1;

  if not found then
    raise exception 'Approved active guard not found.';
  end if;

  update public.patrol_requests
  set guard_id = v_guard.id,
      status = 'assigned',
      assigned_by = public.cp_current_uid(),
      assigned_at = now(),
      updated_at = now()
  where id = v_request.id
  returning * into v_request;

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request), 'guard', row_to_json(v_guard));
end;
$$;

create or replace function public.cp_core_delete_property(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_is_admin boolean := public.cp_is_admin();
  v_property public.properties%rowtype;
  v_client public.clients%rowtype;
begin
  if p_property_id is null then
    raise exception 'Property id is required.';
  end if;

  select * into v_property from public.properties where id = p_property_id limit 1;
  if not found then
    raise exception 'Property not found.';
  end if;

  if not v_is_admin then
    select * into v_client
    from public.clients
    where id = v_property.client_id
      and (auth_user_id = v_uid or lower(email) = v_email)
    limit 1;
    if not found then
      raise exception 'You can only delete your own property.';
    end if;
  end if;

  delete from public.properties where id = p_property_id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.');
  end if;

  v_role := v_profile.role;
  v_client_id := coalesce(v_profile.client_id, (select c.id from public.clients c where c.auth_user_id = v_uid or lower(c.email) = v_email limit 1));
  v_guard_id := coalesce(v_profile.guard_id, (select g.id from public.guards g where g.auth_user_id = v_uid or lower(g.email) = v_email limit 1));

  if v_role = 'admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.created_at desc) from public.patrol_requests r), '[]'::jsonb)
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id = v_client_id or c.auth_user_id = v_uid or lower(c.email) = v_email), '[]'::jsonb),
      'guards', '[]'::jsonb,
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb)
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select r.client_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status = 'assigned')), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id = v_guard_id or g.auth_user_id = v_uid or lower(g.email) = v_email), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select r.property_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status = 'assigned')), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id and r.status = 'assigned'), '[]'::jsonb)
    );
  else
    return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
  end if;
end;
$$;

alter table public.patrol_requests enable row level security;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_submit_patrol_request(uuid, text, text) to authenticated;
grant execute on function public.cp_admin_assign_patrol_request(uuid, uuid) to authenticated;
grant execute on function public.cp_core_delete_property(uuid) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V124_PATROL_STATUS_CORE.sql
-- ============================================================

-- v1.2.4 PATROL STATUS CORE
-- Run once in Supabase SQL Editor after v1.2.3 request dispatch core.
-- Adds only patrol status workflow:
-- 1) Guard accepts assigned request.
-- 2) Guard starts patrol.
-- 3) Guard completes patrol.
-- 4) Admin/client/guard see status/history after refresh.
-- No invite code. No claim code. No admin-created guard/client passwords.
-- No Edge Functions. No proof upload. No final reports. No live ETA.

create extension if not exists pgcrypto;

create table if not exists public.patrol_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  property_id uuid references public.properties(id) on delete set null,
  guard_id uuid references public.guards(id) on delete set null,
  status text not null default 'pending_dispatch',
  priority text not null default 'normal',
  instructions text default '',
  requested_at timestamptz default now(),
  assigned_by uuid,
  assigned_at timestamptz,
  accepted_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.patrol_requests add column if not exists client_id uuid;
alter table public.patrol_requests add column if not exists property_id uuid;
alter table public.patrol_requests add column if not exists guard_id uuid;
alter table public.patrol_requests add column if not exists status text default 'pending_dispatch';
alter table public.patrol_requests add column if not exists priority text default 'normal';
alter table public.patrol_requests add column if not exists instructions text default '';
alter table public.patrol_requests add column if not exists requested_at timestamptz default now();
alter table public.patrol_requests add column if not exists assigned_by uuid;
alter table public.patrol_requests add column if not exists assigned_at timestamptz;
alter table public.patrol_requests add column if not exists accepted_at timestamptz;
alter table public.patrol_requests add column if not exists started_at timestamptz;
alter table public.patrol_requests add column if not exists completed_at timestamptz;
alter table public.patrol_requests add column if not exists created_at timestamptz default now();
alter table public.patrol_requests add column if not exists updated_at timestamptz default now();

create index if not exists patrol_requests_client_id_idx on public.patrol_requests(client_id);
create index if not exists patrol_requests_property_id_idx on public.patrol_requests(property_id);
create index if not exists patrol_requests_guard_id_idx on public.patrol_requests(guard_id);
create index if not exists patrol_requests_status_idx on public.patrol_requests(status);
create index if not exists patrol_requests_created_at_idx on public.patrol_requests(created_at desc);
create index if not exists patrol_requests_updated_at_idx on public.patrol_requests(updated_at desc);

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

create or replace function public.cp_is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (
      p.auth_user_id = public.cp_current_uid()
      or p.id = public.cp_current_uid()
      or lower(coalesce(p.email, '')) = public.cp_current_email()
    )
    and p.role = 'admin'
    and coalesce(p.status, 'active') = 'active'
  );
$$;

create or replace function public.cp_submit_patrol_request(
  p_property_id uuid,
  p_priority text default 'normal',
  p_instructions text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_client public.clients%rowtype;
  v_property public.properties%rowtype;
  v_request public.patrol_requests%rowtype;
  v_priority text := lower(coalesce(nullif(trim(p_priority), ''), 'normal'));
begin
  if p_property_id is null then
    raise exception 'Select a saved property before requesting patrol.';
  end if;

  select * into v_client
  from public.clients
  where auth_user_id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    raise exception 'Approved client record not found.';
  end if;

  select * into v_property
  from public.properties
  where id = p_property_id and client_id = v_client.id
  limit 1;

  if not found then
    raise exception 'You can only request patrol for your own saved property.';
  end if;

  if v_priority not in ('normal', 'high', 'urgent') then
    v_priority := 'normal';
  end if;

  insert into public.patrol_requests (
    id, client_id, property_id, guard_id, status, priority, instructions,
    requested_at, assigned_at, accepted_at, started_at, completed_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_client.id, v_property.id, null, 'pending_dispatch', v_priority,
    coalesce(p_instructions, ''), now(), null, null, null, null, now(), now()
  ) returning * into v_request;

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request));
end;
$$;

create or replace function public.cp_admin_assign_patrol_request(
  p_request_id uuid,
  p_guard_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.patrol_requests%rowtype;
  v_guard public.guards%rowtype;
begin
  if not public.cp_is_admin() then
    raise exception 'Only admin can dispatch patrol requests.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
  limit 1;

  if not found then
    raise exception 'Patrol request not found.';
  end if;

  if coalesce(v_request.status, '') = 'completed' then
    raise exception 'Completed patrol requests cannot be reassigned.';
  end if;

  select * into v_guard
  from public.guards
  where id = p_guard_id and coalesce(status, 'active') = 'active'
  limit 1;

  if not found then
    raise exception 'Approved active guard not found.';
  end if;

  update public.patrol_requests
  set guard_id = v_guard.id,
      status = 'assigned',
      assigned_by = public.cp_current_uid(),
      assigned_at = coalesce(assigned_at, now()),
      updated_at = now()
  where id = v_request.id
  returning * into v_request;

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request), 'guard', row_to_json(v_guard));
end;
$$;

create or replace function public.cp_guard_update_patrol_request_status(
  p_request_id uuid,
  p_next_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_guard public.guards%rowtype;
  v_request public.patrol_requests%rowtype;
  v_next text := lower(coalesce(nullif(trim(p_next_status), ''), ''));
begin
  select * into v_guard
  from public.guards
  where (auth_user_id = v_uid or lower(email) = v_email)
    and coalesce(status, 'active') = 'active'
  limit 1;

  if not found then
    raise exception 'Approved guard record not found.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
    and guard_id = v_guard.id
  for update;

  if not found then
    raise exception 'This patrol request is not assigned to you.';
  end if;

  if v_next not in ('accepted', 'in_progress', 'completed') then
    raise exception 'Invalid patrol status.';
  end if;

  if v_request.status = 'assigned' and v_next <> 'accepted' then
    raise exception 'Accept the patrol before starting it.';
  end if;

  if v_request.status = 'accepted' and v_next <> 'in_progress' then
    raise exception 'Start the patrol before completing it.';
  end if;

  if v_request.status = 'in_progress' and v_next <> 'completed' then
    raise exception 'Complete the patrol or keep it in progress.';
  end if;

  if v_request.status = 'completed' then
    raise exception 'This patrol is already completed.';
  end if;

  update public.patrol_requests
  set status = v_next,
      accepted_at = case when v_next = 'accepted' then coalesce(accepted_at, now()) else accepted_at end,
      started_at = case when v_next = 'in_progress' then coalesce(started_at, now()) else started_at end,
      completed_at = case when v_next = 'completed' then coalesce(completed_at, now()) else completed_at end,
      updated_at = now()
  where id = v_request.id
  returning * into v_request;

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request));
end;
$$;

create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.');
  end if;

  v_role := v_profile.role;
  v_client_id := coalesce(v_profile.client_id, (select c.id from public.clients c where c.auth_user_id = v_uid or lower(c.email) = v_email limit 1));
  v_guard_id := coalesce(v_profile.guard_id, (select g.id from public.guards g where g.auth_user_id = v_uid or lower(g.email) = v_email limit 1));

  if v_role = 'admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r), '[]'::jsonb)
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id = v_client_id or c.auth_user_id = v_uid or lower(c.email) = v_email), '[]'::jsonb),
      'guards', '[]'::jsonb,
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb)
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select r.client_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id = v_guard_id or g.auth_user_id = v_uid or lower(g.email) = v_email), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select r.property_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')), '[]'::jsonb)
    );
  else
    return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
  end if;
end;
$$;

alter table public.patrol_requests enable row level security;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_submit_patrol_request(uuid, text, text) to authenticated;
grant execute on function public.cp_admin_assign_patrol_request(uuid, uuid) to authenticated;
grant execute on function public.cp_guard_update_patrol_request_status(uuid, text) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V125_PROOF_UPLOAD_CORE.sql
-- ============================================================

-- v1.2.5 PROOF UPLOAD CORE
-- Run once in Supabase SQL Editor after v1.2.4 patrol status core.
-- Adds only proof upload/review workflow:
-- 1) Guard uploads photo/video proof to assigned patrols after accepting/starting/completing.
-- 2) Proof is registered to patrol_proof_items.
-- 3) Admin can review proof and mark items for a future report.
-- 4) Client still does NOT see proof files or final reports in this build.
-- No invite code. No claim code. No admin-created guard/client passwords.
-- No Edge Functions. No final reports. No live ETA.

create extension if not exists pgcrypto;

create table if not exists public.patrol_proof_items (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.patrol_requests(id) on delete cascade,
  guard_id uuid references public.guards(id) on delete set null,
  bucket_id text not null default 'patrol-proof',
  object_path text not null,
  file_name text default '',
  file_type text default '',
  file_size bigint default 0,
  public_url text default '',
  note text default '',
  report_selected boolean not null default false,
  uploaded_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.patrol_proof_items add column if not exists request_id uuid;
alter table public.patrol_proof_items add column if not exists guard_id uuid;
alter table public.patrol_proof_items add column if not exists bucket_id text default 'patrol-proof';
alter table public.patrol_proof_items add column if not exists object_path text;
alter table public.patrol_proof_items add column if not exists file_name text default '';
alter table public.patrol_proof_items add column if not exists file_type text default '';
alter table public.patrol_proof_items add column if not exists file_size bigint default 0;
alter table public.patrol_proof_items add column if not exists public_url text default '';
alter table public.patrol_proof_items add column if not exists note text default '';
alter table public.patrol_proof_items add column if not exists report_selected boolean default false;
alter table public.patrol_proof_items add column if not exists uploaded_at timestamptz default now();
alter table public.patrol_proof_items add column if not exists created_at timestamptz default now();
alter table public.patrol_proof_items add column if not exists updated_at timestamptz default now();

create index if not exists patrol_proof_items_request_id_idx on public.patrol_proof_items(request_id);
create index if not exists patrol_proof_items_guard_id_idx on public.patrol_proof_items(guard_id);
create index if not exists patrol_proof_items_uploaded_at_idx on public.patrol_proof_items(uploaded_at desc);
create unique index if not exists patrol_proof_items_object_path_idx on public.patrol_proof_items(bucket_id, object_path);

-- Public bucket is used for v1.2.5 simplicity. Client UI does not expose proof URLs yet.
-- Later v1.2.6/v1.2.7 can move to signed URLs if desired.
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

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

create or replace function public.cp_is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (
      p.auth_user_id = public.cp_current_uid()
      or p.id = public.cp_current_uid()
      or lower(coalesce(p.email, '')) = public.cp_current_email()
    )
    and p.role = 'admin'
    and coalesce(p.status, 'active') = 'active'
  );
$$;

create or replace function public.cp_current_guard_id()
returns uuid
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_guard_id uuid;
begin
  select g.id into v_guard_id
  from public.guards g
  where (g.auth_user_id = v_uid or lower(g.email) = v_email)
    and coalesce(g.status, 'active') = 'active'
  limit 1;

  return v_guard_id;
end;
$$;

create or replace function public.cp_can_upload_patrol_proof_object(p_object_name text)
returns boolean
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_first text := split_part(coalesce(p_object_name, ''), '/', 1);
  v_request_id uuid;
  v_guard_id uuid := public.cp_current_guard_id();
begin
  if v_guard_id is null then
    return false;
  end if;

  if v_first !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;

  v_request_id := v_first::uuid;

  return exists (
    select 1
    from public.patrol_requests r
    where r.id = v_request_id
      and r.guard_id = v_guard_id
      and r.status in ('accepted','in_progress','completed')
  );
end;
$$;

create or replace function public.cp_can_read_patrol_proof_object(p_object_name text)
returns boolean
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_first text := split_part(coalesce(p_object_name, ''), '/', 1);
  v_request_id uuid;
  v_guard_id uuid := public.cp_current_guard_id();
begin
  if public.cp_is_admin() then
    return true;
  end if;

  if v_first !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;

  v_request_id := v_first::uuid;

  return exists (
    select 1
    from public.patrol_requests r
    where r.id = v_request_id
      and r.guard_id = v_guard_id
  );
end;
$$;

drop policy if exists "cp patrol proof guard upload" on storage.objects;
drop policy if exists "cp patrol proof admin guard read" on storage.objects;

create policy "cp patrol proof guard upload"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'patrol-proof'
  and public.cp_can_upload_patrol_proof_object(name)
);

create policy "cp patrol proof admin guard read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'patrol-proof'
  and public.cp_can_read_patrol_proof_object(name)
);

create or replace function public.cp_guard_register_patrol_proof(
  p_request_id uuid,
  p_bucket_id text default 'patrol-proof',
  p_object_path text default '',
  p_file_name text default '',
  p_file_type text default '',
  p_file_size bigint default 0,
  p_public_url text default '',
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guard_id uuid := public.cp_current_guard_id();
  v_request public.patrol_requests%rowtype;
  v_proof public.patrol_proof_items%rowtype;
  v_kind text := lower(coalesce(p_file_type, ''));
begin
  if v_guard_id is null then
    raise exception 'Approved guard record not found.';
  end if;

  if p_request_id is null then
    raise exception 'Patrol request is required.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
    and guard_id = v_guard_id
  limit 1;

  if not found then
    raise exception 'This patrol request is not assigned to you.';
  end if;

  if coalesce(v_request.status, '') not in ('accepted','in_progress','completed') then
    raise exception 'Accept or start the patrol before uploading proof.';
  end if;

  if coalesce(p_bucket_id, '') <> 'patrol-proof' then
    raise exception 'Invalid proof storage bucket.';
  end if;

  if coalesce(p_object_path, '') = '' or p_object_path not like (p_request_id::text || '/%') then
    raise exception 'Invalid proof storage path.';
  end if;

  if not (v_kind like 'image/%' or v_kind like 'video/%') then
    raise exception 'Only photo or video proof files are allowed.';
  end if;

  insert into public.patrol_proof_items (
    id, request_id, guard_id, bucket_id, object_path, file_name, file_type,
    file_size, public_url, note, report_selected, uploaded_at, created_at, updated_at
  ) values (
    gen_random_uuid(), p_request_id, v_guard_id, 'patrol-proof', p_object_path,
    coalesce(p_file_name, ''), coalesce(p_file_type, ''), coalesce(p_file_size, 0),
    coalesce(p_public_url, ''), coalesce(p_note, ''), false, now(), now(), now()
  )
  on conflict (bucket_id, object_path) do update
  set file_name = excluded.file_name,
      file_type = excluded.file_type,
      file_size = excluded.file_size,
      public_url = excluded.public_url,
      note = excluded.note,
      updated_at = now()
  returning * into v_proof;

  return jsonb_build_object('ok', true, 'proof', row_to_json(v_proof));
end;
$$;

create or replace function public.cp_admin_toggle_patrol_proof_report_selected(
  p_proof_id uuid,
  p_report_selected boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_proof public.patrol_proof_items%rowtype;
begin
  if not public.cp_is_admin() then
    raise exception 'Only admin can review/select patrol proof.';
  end if;

  update public.patrol_proof_items
  set report_selected = coalesce(p_report_selected, false),
      updated_at = now()
  where id = p_proof_id
  returning * into v_proof;

  if not found then
    raise exception 'Proof item not found.';
  end if;

  return jsonb_build_object('ok', true, 'proof', row_to_json(v_proof));
end;
$$;

create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.');
  end if;

  v_role := v_profile.role;
  v_client_id := coalesce(v_profile.client_id, (select c.id from public.clients c where c.auth_user_id = v_uid or lower(c.email) = v_email limit 1));
  v_guard_id := coalesce(v_profile.guard_id, (select g.id from public.guards g where g.auth_user_id = v_uid or lower(g.email) = v_email limit 1));

  if v_role = 'admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi), '[]'::jsonb)
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id = v_client_id or c.auth_user_id = v_uid or lower(c.email) = v_email), '[]'::jsonb),
      'guards', '[]'::jsonb,
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb),
      'proofItems', '[]'::jsonb
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select r.client_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id = v_guard_id or g.auth_user_id = v_uid or lower(g.email) = v_email), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select r.property_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.request_id in (select r.id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb)
    );
  else
    return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
  end if;
end;
$$;

alter table public.patrol_proof_items enable row level security;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_current_guard_id() to authenticated;
grant execute on function public.cp_can_upload_patrol_proof_object(text) to authenticated;
grant execute on function public.cp_can_read_patrol_proof_object(text) to authenticated;
grant execute on function public.cp_guard_register_patrol_proof(uuid, text, text, text, text, bigint, text, text) to authenticated;
grant execute on function public.cp_admin_toggle_patrol_proof_report_selected(uuid, boolean) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V126_FINAL_REPORT_BUILDER.sql
-- ============================================================

-- v1.2.6 FINAL REPORT BUILDER
-- Run once in Supabase SQL Editor after v1.2.5 proof upload core.
-- Adds only final report workflow:
-- 1) Admin creates or updates a report for a completed patrol request.
-- 2) Admin can save a draft or release the report to the client.
-- 3) Client sees released report notes and only proof selected for the report.
-- 4) Guard proof upload/review remains from v1.2.5.
-- No invite code. No claim code. No admin-created guard/client passwords.
-- No Edge Functions. No live ETA. No pricing/upgrades.

create extension if not exists pgcrypto;

create table if not exists public.patrol_reports (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.patrol_requests(id) on delete cascade,
  admin_id uuid,
  final_notes text default '',
  status text not null default 'draft',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  released_at timestamptz,
  constraint patrol_reports_request_id_unique unique (request_id),
  constraint patrol_reports_status_check check (status in ('draft','released'))
);

alter table public.patrol_reports add column if not exists request_id uuid;
alter table public.patrol_reports add column if not exists admin_id uuid;
alter table public.patrol_reports add column if not exists final_notes text default '';
alter table public.patrol_reports add column if not exists status text default 'draft';
alter table public.patrol_reports add column if not exists created_at timestamptz default now();
alter table public.patrol_reports add column if not exists updated_at timestamptz default now();
alter table public.patrol_reports add column if not exists released_at timestamptz;

alter table public.patrol_proof_items add column if not exists report_selected boolean default false;
alter table public.patrol_proof_items add column if not exists updated_at timestamptz default now();

create unique index if not exists patrol_reports_request_id_idx on public.patrol_reports(request_id);
create index if not exists patrol_reports_status_idx on public.patrol_reports(status);
create index if not exists patrol_reports_updated_at_idx on public.patrol_reports(updated_at desc);
create index if not exists patrol_proof_items_report_selected_idx on public.patrol_proof_items(report_selected);

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

create or replace function public.cp_is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (
      p.auth_user_id = public.cp_current_uid()
      or p.id = public.cp_current_uid()
      or lower(coalesce(p.email, '')) = public.cp_current_email()
    )
    and p.role = 'admin'
    and coalesce(p.status, 'active') = 'active'
  );
$$;

create or replace function public.cp_admin_save_patrol_report(
  p_request_id uuid,
  p_final_notes text default '',
  p_release boolean default false
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

  insert into public.patrol_reports (
    id, request_id, admin_id, final_notes, status, created_at, updated_at, released_at
  ) values (
    gen_random_uuid(),
    p_request_id,
    public.cp_current_uid(),
    coalesce(p_final_notes, ''),
    v_status,
    now(),
    now(),
    case when coalesce(p_release, false) then now() else null end
  )
  on conflict (request_id) do update
  set admin_id = excluded.admin_id,
      final_notes = excluded.final_notes,
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

  return jsonb_build_object('ok', true, 'report', row_to_json(v_report));
end;
$$;

create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.');
  end if;

  v_role := v_profile.role;
  v_client_id := coalesce(v_profile.client_id, (select c.id from public.clients c where c.auth_user_id = v_uid or lower(c.email) = v_email limit 1));
  v_guard_id := coalesce(v_profile.guard_id, (select g.id from public.guards g where g.auth_user_id = v_uid or lower(g.email) = v_email limit 1));

  if v_role = 'admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.updated_at desc, pr.created_at desc) from public.patrol_reports pr), '[]'::jsonb)
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id = v_client_id or c.auth_user_id = v_uid or lower(c.email) = v_email), '[]'::jsonb),
      'guards', '[]'::jsonb,
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb),
      'proofItems', coalesce((
        select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc)
        from public.patrol_proof_items pi
        join public.patrol_reports pr on pr.request_id = pi.request_id and pr.status = 'released'
        join public.patrol_requests r on r.id = pi.request_id
        where r.client_id = v_client_id
          and coalesce(pi.report_selected, false) = true
      ), '[]'::jsonb),
      'patrolReports', coalesce((
        select jsonb_agg(row_to_json(pr) order by pr.released_at desc nulls last, pr.updated_at desc)
        from public.patrol_reports pr
        join public.patrol_requests r on r.id = pr.request_id
        where r.client_id = v_client_id
          and pr.status = 'released'
      ), '[]'::jsonb)
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select r.client_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id = v_guard_id or g.auth_user_id = v_uid or lower(g.email) = v_email), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select r.property_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.request_id in (select r.id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolReports', '[]'::jsonb
    );
  else
    return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
  end if;
end;
$$;

alter table public.patrol_reports enable row level security;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_admin_save_patrol_report(uuid, text, boolean) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V127_REQUEST_OPTIONS.sql
-- ============================================================

-- v1.2.7 REQUEST OPTIONS CORE
-- Run once in Supabase SQL Editor after v1.2.6 is installed.
-- Adds client patrol request options without adding pricing.
-- No invite code. No claim code. No admin-created guard/client passwords.
-- No Edge Functions. No live ETA/GPS map.

create extension if not exists pgcrypto;

alter table public.patrol_requests add column if not exists patrol_type text default 'standard';
alter table public.patrol_requests add column if not exists proof_preference text default 'photo';

update public.patrol_requests
set patrol_type = coalesce(nullif(trim(patrol_type), ''), 'standard'),
    proof_preference = coalesce(nullif(trim(proof_preference), ''), 'photo')
where patrol_type is null or trim(patrol_type) = '' or proof_preference is null or trim(proof_preference) = '';

create index if not exists patrol_requests_patrol_type_idx on public.patrol_requests(patrol_type);
create index if not exists patrol_requests_proof_preference_idx on public.patrol_requests(proof_preference);

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

drop function if exists public.cp_submit_patrol_request(uuid, text, text);
drop function if exists public.cp_submit_patrol_request(uuid, text, text, text, text);

create or replace function public.cp_submit_patrol_request(
  p_property_id uuid,
  p_priority text default 'normal',
  p_instructions text default '',
  p_patrol_type text default 'standard',
  p_proof_preference text default 'photo'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_client public.clients%rowtype;
  v_property public.properties%rowtype;
  v_request public.patrol_requests%rowtype;
  v_priority text := lower(coalesce(nullif(trim(p_priority), ''), 'normal'));
  v_patrol_type text := lower(coalesce(nullif(trim(p_patrol_type), ''), 'standard'));
  v_proof_preference text := lower(coalesce(nullif(trim(p_proof_preference), ''), 'photo'));
begin
  if p_property_id is null then
    raise exception 'Select a saved property before requesting patrol.';
  end if;

  select * into v_client
  from public.clients
  where auth_user_id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    raise exception 'Approved client record not found.';
  end if;

  select * into v_property
  from public.properties
  where id = p_property_id and client_id = v_client.id
  limit 1;

  if not found then
    raise exception 'You can only request patrol for your own saved property.';
  end if;

  if v_priority not in ('normal', 'high', 'urgent') then
    v_priority := 'normal';
  end if;

  if v_patrol_type not in ('standard', 'urgent', 'vacation_watch', 'suspicious_activity', 'alarm_response', 'custom') then
    v_patrol_type := 'standard';
  end if;

  if v_proof_preference not in ('photo', 'video', 'photo_video', 'none') then
    v_proof_preference := 'photo';
  end if;

  insert into public.patrol_requests (
    id, client_id, property_id, guard_id, status, priority, instructions,
    patrol_type, proof_preference,
    requested_at, assigned_at, accepted_at, started_at, completed_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_client.id, v_property.id, null, 'pending_dispatch', v_priority,
    coalesce(p_instructions, ''), v_patrol_type, v_proof_preference,
    now(), null, null, null, null, now(), now()
  ) returning * into v_request;

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request));
end;
$$;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_submit_patrol_request(uuid, text, text, text, text) to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V128_TIMELINE_NOTIFICATIONS.sql
-- ============================================================

-- v1.2.8 TIMELINE + IN-APP NOTIFICATIONS CORE
-- Run once in Supabase SQL Editor after v1.2.7 request options is installed.
-- Adds only in-app notifications and patrol activity/timeline records.
-- No pricing. No SMS/email. No live ETA/GPS map. No invite codes. No claim codes.

create extension if not exists pgcrypto;

create table if not exists public.cp_patrol_activity_log (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.patrol_requests(id) on delete cascade,
  actor_role text default '',
  actor_id uuid,
  actor_name text default '',
  event_type text not null,
  title text not null,
  details text default '',
  created_at timestamptz default now()
);

create table if not exists public.cp_in_app_notifications (
  id uuid primary key default gen_random_uuid(),
  target_role text not null,
  target_profile_id uuid,
  client_id uuid,
  guard_id uuid,
  request_id uuid references public.patrol_requests(id) on delete cascade,
  title text not null,
  message text default '',
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz default now()
);

alter table public.cp_patrol_activity_log add column if not exists request_id uuid;
alter table public.cp_patrol_activity_log add column if not exists actor_role text default '';
alter table public.cp_patrol_activity_log add column if not exists actor_id uuid;
alter table public.cp_patrol_activity_log add column if not exists actor_name text default '';
alter table public.cp_patrol_activity_log add column if not exists event_type text default '';
alter table public.cp_patrol_activity_log add column if not exists title text default '';
alter table public.cp_patrol_activity_log add column if not exists details text default '';
alter table public.cp_patrol_activity_log add column if not exists created_at timestamptz default now();

alter table public.cp_in_app_notifications add column if not exists target_role text default '';
alter table public.cp_in_app_notifications add column if not exists target_profile_id uuid;
alter table public.cp_in_app_notifications add column if not exists client_id uuid;
alter table public.cp_in_app_notifications add column if not exists guard_id uuid;
alter table public.cp_in_app_notifications add column if not exists request_id uuid;
alter table public.cp_in_app_notifications add column if not exists title text default '';
alter table public.cp_in_app_notifications add column if not exists message text default '';
alter table public.cp_in_app_notifications add column if not exists is_read boolean default false;
alter table public.cp_in_app_notifications add column if not exists read_at timestamptz;
alter table public.cp_in_app_notifications add column if not exists created_at timestamptz default now();

create index if not exists cp_patrol_activity_log_request_id_idx on public.cp_patrol_activity_log(request_id);
create index if not exists cp_patrol_activity_log_created_at_idx on public.cp_patrol_activity_log(created_at desc);
create index if not exists cp_patrol_activity_log_event_type_idx on public.cp_patrol_activity_log(event_type);
create index if not exists cp_notifications_target_role_idx on public.cp_in_app_notifications(target_role);
create index if not exists cp_notifications_client_id_idx on public.cp_in_app_notifications(client_id);
create index if not exists cp_notifications_guard_id_idx on public.cp_in_app_notifications(guard_id);
create index if not exists cp_notifications_request_id_idx on public.cp_in_app_notifications(request_id);
create index if not exists cp_notifications_unread_idx on public.cp_in_app_notifications(is_read, created_at desc);

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

create or replace function public.cp_is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1 from public.profiles p
    where (
      p.auth_user_id = public.cp_current_uid()
      or p.id = public.cp_current_uid()
      or lower(coalesce(p.email, '')) = public.cp_current_email()
    )
    and p.role = 'admin'
    and coalesce(p.status, 'active') = 'active'
  );
$$;

create or replace function public.cp_current_guard_id()
returns uuid
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_guard_id uuid;
begin
  select g.id into v_guard_id
  from public.guards g
  where (g.auth_user_id = v_uid or lower(g.email) = v_email)
    and coalesce(g.status, 'active') = 'active'
  limit 1;

  return v_guard_id;
end;
$$;

create or replace function public.cp_current_client_id()
returns uuid
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_client_id uuid;
begin
  select c.id into v_client_id
  from public.clients c
  where (c.auth_user_id = v_uid or lower(c.email) = v_email)
    and coalesce(c.status, 'active') = 'active'
  limit 1;

  return v_client_id;
end;
$$;

create or replace function public.cp_current_actor_name()
returns text
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_name text;
begin
  select coalesce(nullif(trim(p.display_name), ''), p.email, '') into v_name
  from public.profiles p
  where p.auth_user_id = v_uid or p.id = v_uid or lower(p.email) = v_email
  limit 1;

  return coalesce(v_name, 'System');
end;
$$;

create or replace function public.cp_add_patrol_activity(
  p_request_id uuid,
  p_actor_role text,
  p_actor_id uuid,
  p_actor_name text,
  p_event_type text,
  p_title text,
  p_details text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_request_id is null then
    return null;
  end if;

  insert into public.cp_patrol_activity_log (
    request_id, actor_role, actor_id, actor_name, event_type, title, details, created_at
  ) values (
    p_request_id,
    coalesce(p_actor_role, ''),
    p_actor_id,
    coalesce(p_actor_name, ''),
    coalesce(nullif(trim(p_event_type), ''), 'activity'),
    coalesce(nullif(trim(p_title), ''), 'Patrol activity'),
    coalesce(p_details, ''),
    now()
  ) returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.cp_create_notification(
  p_target_role text,
  p_client_id uuid,
  p_guard_id uuid,
  p_request_id uuid,
  p_title text,
  p_message text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_role text := lower(coalesce(nullif(trim(p_target_role), ''), ''));
begin
  if v_role not in ('admin','guard','client') then
    return null;
  end if;

  insert into public.cp_in_app_notifications (
    target_role, client_id, guard_id, request_id, title, message, is_read, created_at
  ) values (
    v_role,
    p_client_id,
    p_guard_id,
    p_request_id,
    coalesce(nullif(trim(p_title), ''), 'Notification'),
    coalesce(p_message, ''),
    false,
    now()
  ) returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.cp_submit_patrol_request(
  p_property_id uuid,
  p_priority text default 'normal',
  p_instructions text default '',
  p_patrol_type text default 'standard',
  p_proof_preference text default 'photo'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_client public.clients%rowtype;
  v_property public.properties%rowtype;
  v_request public.patrol_requests%rowtype;
  v_priority text := lower(coalesce(nullif(trim(p_priority), ''), 'normal'));
  v_patrol_type text := lower(coalesce(nullif(trim(p_patrol_type), ''), 'standard'));
  v_proof_preference text := lower(coalesce(nullif(trim(p_proof_preference), ''), 'photo'));
begin
  if p_property_id is null then
    raise exception 'Select a saved property before requesting patrol.';
  end if;

  select * into v_client
  from public.clients
  where auth_user_id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    raise exception 'Approved client record not found.';
  end if;

  select * into v_property
  from public.properties
  where id = p_property_id and client_id = v_client.id
  limit 1;

  if not found then
    raise exception 'You can only request patrol for your own saved property.';
  end if;

  if v_priority not in ('normal', 'high', 'urgent') then
    v_priority := 'normal';
  end if;

  if v_patrol_type not in ('standard', 'urgent', 'vacation_watch', 'suspicious_activity', 'alarm_response', 'custom') then
    v_patrol_type := 'standard';
  end if;

  if v_proof_preference not in ('photo', 'video', 'photo_video', 'none') then
    v_proof_preference := 'photo';
  end if;

  insert into public.patrol_requests (
    id, client_id, property_id, guard_id, status, priority, instructions,
    patrol_type, proof_preference,
    requested_at, assigned_at, accepted_at, started_at, completed_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_client.id, v_property.id, null, 'pending_dispatch', v_priority,
    coalesce(p_instructions, ''), v_patrol_type, v_proof_preference,
    now(), null, null, null, null, now(), now()
  ) returning * into v_request;

  perform public.cp_add_patrol_activity(
    v_request.id, 'client', v_client.id, v_client.name, 'request_submitted',
    'Client submitted patrol request',
    coalesce(v_property.label, 'Property') || ' • ' || coalesce(v_priority, 'normal') || ' priority'
  );

  perform public.cp_create_notification(
    'admin', v_client.id, null, v_request.id,
    'New patrol request',
    coalesce(v_client.name, 'Client') || ' submitted a patrol request for ' || coalesce(v_property.label, 'a property') || '.'
  );

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request));
end;
$$;

create or replace function public.cp_admin_assign_patrol_request(
  p_request_id uuid,
  p_guard_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.patrol_requests%rowtype;
  v_guard public.guards%rowtype;
  v_client public.clients%rowtype;
  v_actor_name text := public.cp_current_actor_name();
begin
  if not public.cp_is_admin() then
    raise exception 'Only admin can dispatch patrol requests.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
  limit 1;

  if not found then
    raise exception 'Patrol request not found.';
  end if;

  if coalesce(v_request.status, '') = 'completed' then
    raise exception 'Completed patrol requests cannot be reassigned.';
  end if;

  select * into v_guard
  from public.guards
  where id = p_guard_id and coalesce(status, 'active') = 'active'
  limit 1;

  if not found then
    raise exception 'Approved active guard not found.';
  end if;

  select * into v_client from public.clients where id = v_request.client_id limit 1;

  update public.patrol_requests
  set guard_id = v_guard.id,
      status = 'assigned',
      assigned_by = public.cp_current_uid(),
      assigned_at = coalesce(assigned_at, now()),
      updated_at = now()
  where id = v_request.id
  returning * into v_request;

  perform public.cp_add_patrol_activity(
    v_request.id, 'admin', public.cp_current_uid(), v_actor_name, 'guard_assigned',
    'Admin assigned guard',
    coalesce(v_guard.name, 'Guard') || ' assigned to patrol request.'
  );

  perform public.cp_create_notification(
    'guard', v_request.client_id, v_guard.id, v_request.id,
    'New patrol assignment',
    'You have been assigned a patrol request.'
  );

  perform public.cp_create_notification(
    'client', v_request.client_id, v_guard.id, v_request.id,
    'Guard assigned',
    coalesce(v_guard.name, 'A guard') || ' has been assigned to your patrol request.'
  );

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request), 'guard', row_to_json(v_guard));
end;
$$;

create or replace function public.cp_guard_update_patrol_request_status(
  p_request_id uuid,
  p_next_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_guard public.guards%rowtype;
  v_request public.patrol_requests%rowtype;
  v_next text := lower(coalesce(nullif(trim(p_next_status), ''), ''));
  v_title text;
  v_message text;
  v_event text;
begin
  select * into v_guard
  from public.guards
  where (auth_user_id = v_uid or lower(email) = v_email)
    and coalesce(status, 'active') = 'active'
  limit 1;

  if not found then
    raise exception 'Approved guard record not found.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
    and guard_id = v_guard.id
  for update;

  if not found then
    raise exception 'This patrol request is not assigned to you.';
  end if;

  if v_next not in ('accepted', 'in_progress', 'completed') then
    raise exception 'Invalid patrol status.';
  end if;

  if v_request.status = 'assigned' and v_next <> 'accepted' then
    raise exception 'Accept the patrol before starting it.';
  end if;

  if v_request.status = 'accepted' and v_next <> 'in_progress' then
    raise exception 'Start the patrol before completing it.';
  end if;

  if v_request.status = 'in_progress' and v_next <> 'completed' then
    raise exception 'Complete the patrol or keep it in progress.';
  end if;

  if v_request.status = 'completed' then
    raise exception 'This patrol is already completed.';
  end if;

  update public.patrol_requests
  set status = v_next,
      accepted_at = case when v_next = 'accepted' then coalesce(accepted_at, now()) else accepted_at end,
      started_at = case when v_next = 'in_progress' then coalesce(started_at, now()) else started_at end,
      completed_at = case when v_next = 'completed' then coalesce(completed_at, now()) else completed_at end,
      updated_at = now()
  where id = v_request.id
  returning * into v_request;

  v_event := case v_next when 'accepted' then 'guard_accepted' when 'in_progress' then 'patrol_started' else 'patrol_completed' end;
  v_title := case v_next when 'accepted' then 'Guard accepted patrol' when 'in_progress' then 'Guard started patrol' else 'Guard completed patrol' end;
  v_message := case v_next when 'accepted' then 'The assigned guard accepted your patrol request.' when 'in_progress' then 'Your patrol is now in progress.' else 'Your patrol has been completed.' end;

  perform public.cp_add_patrol_activity(
    v_request.id, 'guard', v_guard.id, v_guard.name, v_event, v_title, v_message
  );

  perform public.cp_create_notification(
    'client', v_request.client_id, v_guard.id, v_request.id, v_title, v_message
  );

  perform public.cp_create_notification(
    'admin', v_request.client_id, v_guard.id, v_request.id, v_title, coalesce(v_guard.name, 'Guard') || ': ' || v_message
  );

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request));
end;
$$;

create or replace function public.cp_guard_register_patrol_proof(
  p_request_id uuid,
  p_bucket_id text default 'patrol-proof',
  p_object_path text default '',
  p_file_name text default '',
  p_file_type text default '',
  p_file_size bigint default 0,
  p_public_url text default '',
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guard_id uuid := public.cp_current_guard_id();
  v_guard public.guards%rowtype;
  v_request public.patrol_requests%rowtype;
  v_proof public.patrol_proof_items%rowtype;
  v_kind text := lower(coalesce(p_file_type, ''));
begin
  if v_guard_id is null then
    raise exception 'Approved guard record not found.';
  end if;

  select * into v_guard from public.guards where id = v_guard_id limit 1;

  if p_request_id is null then
    raise exception 'Patrol request is required.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
    and guard_id = v_guard_id
  limit 1;

  if not found then
    raise exception 'This patrol request is not assigned to you.';
  end if;

  if coalesce(v_request.status, '') not in ('accepted','in_progress','completed') then
    raise exception 'Accept or start the patrol before uploading proof.';
  end if;

  if coalesce(p_bucket_id, '') <> 'patrol-proof' then
    raise exception 'Invalid proof storage bucket.';
  end if;

  if coalesce(p_object_path, '') = '' or p_object_path not like (p_request_id::text || '/%') then
    raise exception 'Invalid proof storage path.';
  end if;

  if not (v_kind like 'image/%' or v_kind like 'video/%') then
    raise exception 'Only photo or video proof files are allowed.';
  end if;

  insert into public.patrol_proof_items (
    id, request_id, guard_id, bucket_id, object_path, file_name, file_type,
    file_size, public_url, note, report_selected, uploaded_at, created_at, updated_at
  ) values (
    gen_random_uuid(), p_request_id, v_guard_id, 'patrol-proof', p_object_path,
    coalesce(p_file_name, ''), coalesce(p_file_type, ''), coalesce(p_file_size, 0),
    coalesce(p_public_url, ''), coalesce(p_note, ''), false, now(), now(), now()
  )
  on conflict (bucket_id, object_path) do update
  set file_name = excluded.file_name,
      file_type = excluded.file_type,
      file_size = excluded.file_size,
      public_url = excluded.public_url,
      note = excluded.note,
      updated_at = now()
  returning * into v_proof;

  perform public.cp_add_patrol_activity(
    p_request_id, 'guard', v_guard_id, coalesce(v_guard.name, 'Guard'), 'proof_uploaded',
    'Guard uploaded proof',
    coalesce(nullif(trim(p_note), ''), coalesce(p_file_name, 'Proof file uploaded'))
  );

  perform public.cp_create_notification(
    'admin', v_request.client_id, v_guard_id, p_request_id,
    'Proof uploaded',
    coalesce(v_guard.name, 'Guard') || ' uploaded patrol proof.'
  );

  return jsonb_build_object('ok', true, 'proof', row_to_json(v_proof));
end;
$$;

create or replace function public.cp_admin_save_patrol_report(
  p_request_id uuid,
  p_final_notes text default '',
  p_release boolean default false
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

  insert into public.patrol_reports (
    id, request_id, admin_id, final_notes, status, created_at, updated_at, released_at
  ) values (
    gen_random_uuid(),
    p_request_id,
    public.cp_current_uid(),
    coalesce(p_final_notes, ''),
    v_status,
    now(),
    now(),
    case when coalesce(p_release, false) then now() else null end
  )
  on conflict (request_id) do update
  set admin_id = excluded.admin_id,
      final_notes = excluded.final_notes,
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
    case when coalesce(p_release, false) then 'Admin released final report' else 'Admin saved report draft' end,
    case when coalesce(p_release, false) then 'Final report is ready for the client.' else 'Final report draft was saved.' end
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

create or replace function public.cp_mark_notifications_read(p_notification_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_client_id uuid;
  v_guard_id uuid;
  v_count integer := 0;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    raise exception 'Approved profile not found.';
  end if;

  v_client_id := coalesce(v_profile.client_id, public.cp_current_client_id());
  v_guard_id := coalesce(v_profile.guard_id, public.cp_current_guard_id());

  if v_profile.role = 'admin' then
    update public.cp_in_app_notifications
    set is_read = true, read_at = coalesce(read_at, now())
    where target_role = 'admin'
      and (p_notification_id is null or id = p_notification_id);
  elsif v_profile.role = 'client' then
    update public.cp_in_app_notifications
    set is_read = true, read_at = coalesce(read_at, now())
    where target_role = 'client'
      and client_id = v_client_id
      and (p_notification_id is null or id = p_notification_id);
  elsif v_profile.role = 'guard' then
    update public.cp_in_app_notifications
    set is_read = true, read_at = coalesce(read_at, now())
    where target_role = 'guard'
      and guard_id = v_guard_id
      and (p_notification_id is null or id = p_notification_id);
  else
    raise exception 'Unknown role.';
  end if;

  get diagnostics v_count = row_count;
  return jsonb_build_object('ok', true, 'updated', v_count);
end;
$$;

create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.');
  end if;

  v_role := v_profile.role;
  v_client_id := coalesce(v_profile.client_id, public.cp_current_client_id());
  v_guard_id := coalesce(v_profile.guard_id, public.cp_current_guard_id());

  if v_role = 'admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.updated_at desc, pr.created_at desc) from public.patrol_reports pr), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.target_role = 'admin'), '[]'::jsonb),
      'patrolActivity', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.cp_patrol_activity_log a), '[]'::jsonb)
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id = v_client_id or c.auth_user_id = v_uid or lower(c.email) = v_email), '[]'::jsonb),
      'guards', '[]'::jsonb,
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb),
      'proofItems', coalesce((
        select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc)
        from public.patrol_proof_items pi
        join public.patrol_reports pr on pr.request_id = pi.request_id and pr.status = 'released'
        join public.patrol_requests r on r.id = pi.request_id
        where r.client_id = v_client_id
          and coalesce(pi.report_selected, false) = true
      ), '[]'::jsonb),
      'patrolReports', coalesce((
        select jsonb_agg(row_to_json(pr) order by pr.released_at desc nulls last, pr.updated_at desc)
        from public.patrol_reports pr
        join public.patrol_requests r on r.id = pr.request_id
        where r.client_id = v_client_id
          and pr.status = 'released'
      ), '[]'::jsonb),
      'notifications', coalesce((
        select jsonb_agg(row_to_json(n) order by n.created_at desc)
        from public.cp_in_app_notifications n
        where n.target_role = 'client' and n.client_id = v_client_id
      ), '[]'::jsonb),
      'patrolActivity', coalesce((
        select jsonb_agg(row_to_json(a) order by a.created_at desc)
        from public.cp_patrol_activity_log a
        join public.patrol_requests r on r.id = a.request_id
        where r.client_id = v_client_id
      ), '[]'::jsonb)
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select r.client_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id = v_guard_id or g.auth_user_id = v_uid or lower(g.email) = v_email), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select r.property_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.request_id in (select r.id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolReports', '[]'::jsonb,
      'notifications', coalesce((
        select jsonb_agg(row_to_json(n) order by n.created_at desc)
        from public.cp_in_app_notifications n
        where n.target_role = 'guard' and n.guard_id = v_guard_id
      ), '[]'::jsonb),
      'patrolActivity', coalesce((
        select jsonb_agg(row_to_json(a) order by a.created_at desc)
        from public.cp_patrol_activity_log a
        join public.patrol_requests r on r.id = a.request_id
        where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')
      ), '[]'::jsonb)
    );
  else
    return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
  end if;
end;
$$;

alter table public.cp_patrol_activity_log enable row level security;
alter table public.cp_in_app_notifications enable row level security;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_current_guard_id() to authenticated;
grant execute on function public.cp_current_client_id() to authenticated;
grant execute on function public.cp_current_actor_name() to authenticated;
grant execute on function public.cp_submit_patrol_request(uuid, text, text, text, text) to authenticated;
grant execute on function public.cp_admin_assign_patrol_request(uuid, uuid) to authenticated;
grant execute on function public.cp_guard_update_patrol_request_status(uuid, text) to authenticated;
grant execute on function public.cp_guard_register_patrol_proof(uuid, text, text, text, text, bigint, text, text) to authenticated;
grant execute on function public.cp_admin_save_patrol_report(uuid, text, boolean) to authenticated;
grant execute on function public.cp_mark_notifications_read(uuid) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V129_GPS_ETA_CORE.sql
-- ============================================================

-- v1.2.9 GPS / ETA CORE
-- Run once in Supabase SQL Editor after RUN_ONCE_V128_TIMELINE_NOTIFICATIONS.sql.
-- Adds stable browser-GPS tracking without pricing, SMS/email, Edge Functions, invite codes, claim codes, or paid map APIs.

alter table public.guards add column if not exists current_accuracy double precision;
alter table public.guards add column if not exists last_seen_at timestamptz;
create index if not exists guards_last_seen_at_idx on public.guards(last_seen_at desc);
create index if not exists guards_current_location_idx on public.guards(current_lat, current_lng);

create or replace function public.cp_guard_share_live_location(
  p_request_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_guard public.guards%rowtype;
  v_request public.patrol_requests%rowtype;
  v_actor_name text := public.cp_current_actor_name();
  v_first_share boolean := false;
begin
  if p_request_id is null then
    raise exception 'Select an active patrol before sharing GPS.';
  end if;

  if p_lat is null or p_lng is null then
    raise exception 'Browser GPS did not return latitude/longitude.';
  end if;

  if p_lat < -90 or p_lat > 90 or p_lng < -180 or p_lng > 180 then
    raise exception 'Invalid GPS coordinates.';
  end if;

  select * into v_guard
  from public.guards
  where (auth_user_id = v_uid or lower(email) = v_email)
    and coalesce(status, 'active') = 'active'
  limit 1;

  if not found then
    raise exception 'Approved guard record not found.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
    and guard_id = v_guard.id
  limit 1;

  if not found then
    raise exception 'This patrol is not assigned to your guard account.';
  end if;

  if coalesce(v_request.status, '') not in ('assigned','accepted','in_progress') then
    raise exception 'GPS sharing is only available while a patrol is assigned, accepted, or in progress.';
  end if;

  select not exists (
    select 1 from public.cp_patrol_activity_log a
    where a.request_id = v_request.id
      and a.event_type = 'live_location_started'
  ) into v_first_share;

  update public.guards
  set availability_status = 'online',
      is_available = true,
      current_lat = p_lat,
      current_lng = p_lng,
      current_accuracy = p_accuracy,
      last_seen_at = now(),
      updated_at = now()
  where id = v_guard.id
  returning * into v_guard;

  if v_first_share then
    perform public.cp_add_patrol_activity(
      v_request.id,
      'guard',
      v_guard.id,
      coalesce(nullif(trim(v_guard.name), ''), v_actor_name, 'Guard'),
      'live_location_started',
      'Guard started live GPS sharing',
      'Guard browser GPS is now available for this active patrol.'
    );

    perform public.cp_create_notification(
      'admin', v_request.client_id, v_guard.id, v_request.id,
      'Guard GPS sharing started',
      coalesce(nullif(trim(v_guard.name), ''), 'A guard') || ' started sharing live GPS for an active patrol.'
    );

    perform public.cp_create_notification(
      'client', v_request.client_id, v_guard.id, v_request.id,
      'Guard GPS is live',
      'Your assigned guard has started sharing live GPS for this patrol.'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'guard', row_to_json(v_guard),
    'request', row_to_json(v_request),
    'firstShare', v_first_share
  );
end;
$$;

create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.');
  end if;

  v_role := v_profile.role;
  v_client_id := coalesce(v_profile.client_id, public.cp_current_client_id());
  v_guard_id := coalesce(v_profile.guard_id, public.cp_current_guard_id());

  if v_role = 'admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.updated_at desc, pr.created_at desc) from public.patrol_reports pr), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.target_role = 'admin'), '[]'::jsonb),
      'patrolActivity', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.cp_patrol_activity_log a), '[]'::jsonb)
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id = v_client_id or c.auth_user_id = v_uid or lower(c.email) = v_email), '[]'::jsonb),
      'guards', coalesce((
        select jsonb_agg(row_to_json(g) order by g.updated_at desc, g.last_seen_at desc nulls last)
        from public.guards g
        where g.id in (
          select r.guard_id
          from public.patrol_requests r
          where r.client_id = v_client_id
            and r.status in ('assigned','accepted','in_progress')
            and r.guard_id is not null
        )
      ), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb),
      'proofItems', coalesce((
        select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc)
        from public.patrol_proof_items pi
        join public.patrol_reports pr on pr.request_id = pi.request_id and pr.status = 'released'
        join public.patrol_requests r on r.id = pi.request_id
        where r.client_id = v_client_id
          and coalesce(pi.report_selected, false) = true
      ), '[]'::jsonb),
      'patrolReports', coalesce((
        select jsonb_agg(row_to_json(pr) order by pr.released_at desc nulls last, pr.updated_at desc)
        from public.patrol_reports pr
        join public.patrol_requests r on r.id = pr.request_id
        where r.client_id = v_client_id
          and pr.status = 'released'
      ), '[]'::jsonb),
      'notifications', coalesce((
        select jsonb_agg(row_to_json(n) order by n.created_at desc)
        from public.cp_in_app_notifications n
        where n.target_role = 'client' and n.client_id = v_client_id
      ), '[]'::jsonb),
      'patrolActivity', coalesce((
        select jsonb_agg(row_to_json(a) order by a.created_at desc)
        from public.cp_patrol_activity_log a
        join public.patrol_requests r on r.id = a.request_id
        where r.client_id = v_client_id
      ), '[]'::jsonb)
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select r.client_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id = v_guard_id or g.auth_user_id = v_uid or lower(g.email) = v_email), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select r.property_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.request_id in (select r.id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolReports', '[]'::jsonb,
      'notifications', coalesce((
        select jsonb_agg(row_to_json(n) order by n.created_at desc)
        from public.cp_in_app_notifications n
        where n.target_role = 'guard' and n.guard_id = v_guard_id
      ), '[]'::jsonb),
      'patrolActivity', coalesce((
        select jsonb_agg(row_to_json(a) order by a.created_at desc)
        from public.cp_patrol_activity_log a
        join public.patrol_requests r on r.id = a.request_id
        where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')
      ), '[]'::jsonb)
    );
  else
    return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
  end if;
end;
$$;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_guard_share_live_location(uuid, double precision, double precision, double precision) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V1210_EMBEDDED_LIVE_MAP_CORE.sql
-- ============================================================

-- Co Pilot Security Patrol v1.2.10 — Embedded Live Map Core
-- No new schema/RPC changes are required in this build.
-- This build uses the guard GPS/property coordinate columns and RPC from RUN_ONCE_V129_GPS_ETA_CORE.sql.
-- Run RUN_ONCE_V129_GPS_ETA_CORE.sql first if you have not already run it.

select 'v1.2.10 embedded live map core loaded: no schema changes required; v1.2.9 GPS SQL still required.' as status;


-- ============================================================
-- Included from RUN_ONCE_V1211_COMMAND_CENTER_MAP_HUB.sql
-- ============================================================

-- Co Pilot Security Patrol v1.2.11 Command Center Map Hub
-- No new schema required.
-- This file is included as a build marker only.
-- Requirement: RUN_ONCE_V129_GPS_ETA_CORE.sql must already be run for GPS/RPC support.
select 'v1.2.11 command center map hub loaded - no schema changes required' as status;


-- ============================================================
-- Included from RUN_ONCE_V1212_MOBILE_ROAD_ROUTE_MAP.sql
-- ============================================================

-- v1.2.12 Mobile Road Route Map
-- No database changes required.
-- Keep this file only as a version marker for deployment notes.
select 'v1.2.12 mobile road route map - no SQL changes required' as status;


-- ============================================================
-- Included from RUN_ONCE_V1213_MAP_RULES_UBER_POLISH.sql
-- ============================================================

-- Co Pilot Security Patrol v1.2.13
-- Map Rules / Uber Polish
-- No schema changes required.
-- Run RUN_ONCE_V129_GPS_ETA_CORE.sql first if it has not already been run.
select 'v1.2.13 map rules / uber polish marker - no schema changes required' as status;


-- ============================================================
-- Included from RUN_ONCE_V1214_IN_APP_MESSAGING_CORE.sql
-- ============================================================

-- Co Pilot Security Patrol v1.2.14
-- In-App Messaging Core
-- Run once after v1.2.13 / after RUN_ONCE_V129_GPS_ETA_CORE.sql.
-- Adds Admin <-> Guard and Admin <-> Client in-app messaging.
-- No SMS, email, invite codes, claim codes, pricing, or Edge Functions.

create table if not exists public.cp_message_threads (
  id uuid primary key default gen_random_uuid(),
  thread_type text not null default 'direct',
  admin_profile_id uuid,
  client_id uuid references public.clients(id) on delete cascade,
  guard_id uuid references public.guards(id) on delete cascade,
  title text default '',
  last_message text default '',
  last_message_at timestamptz,
  admin_last_read_at timestamptz,
  client_last_read_at timestamptz,
  guard_last_read_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.cp_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.cp_message_threads(id) on delete cascade,
  sender_profile_id uuid,
  sender_role text not null default '',
  sender_name text default '',
  body text not null default '',
  is_system boolean default false,
  created_at timestamptz default now()
);

alter table public.cp_message_threads add column if not exists thread_type text not null default 'direct';
alter table public.cp_message_threads add column if not exists admin_profile_id uuid;
alter table public.cp_message_threads add column if not exists client_id uuid;
alter table public.cp_message_threads add column if not exists guard_id uuid;
alter table public.cp_message_threads add column if not exists title text default '';
alter table public.cp_message_threads add column if not exists last_message text default '';
alter table public.cp_message_threads add column if not exists last_message_at timestamptz;
alter table public.cp_message_threads add column if not exists admin_last_read_at timestamptz;
alter table public.cp_message_threads add column if not exists client_last_read_at timestamptz;
alter table public.cp_message_threads add column if not exists guard_last_read_at timestamptz;
alter table public.cp_message_threads add column if not exists created_at timestamptz default now();
alter table public.cp_message_threads add column if not exists updated_at timestamptz default now();

alter table public.cp_messages add column if not exists thread_id uuid;
alter table public.cp_messages add column if not exists sender_profile_id uuid;
alter table public.cp_messages add column if not exists sender_role text not null default '';
alter table public.cp_messages add column if not exists sender_name text default '';
alter table public.cp_messages add column if not exists body text not null default '';
alter table public.cp_messages add column if not exists is_system boolean default false;
alter table public.cp_messages add column if not exists created_at timestamptz default now();

create unique index if not exists cp_message_threads_client_unique
  on public.cp_message_threads(client_id)
  where client_id is not null and guard_id is null;

create unique index if not exists cp_message_threads_guard_unique
  on public.cp_message_threads(guard_id)
  where guard_id is not null and client_id is null;

create index if not exists cp_message_threads_updated_idx on public.cp_message_threads(updated_at desc);
create index if not exists cp_message_threads_client_idx on public.cp_message_threads(client_id);
create index if not exists cp_message_threads_guard_idx on public.cp_message_threads(guard_id);
create index if not exists cp_messages_thread_created_idx on public.cp_messages(thread_id, created_at asc);
create index if not exists cp_messages_sender_profile_idx on public.cp_messages(sender_profile_id);

create or replace function public.cp_can_access_message_thread(p_thread_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_client_id uuid;
  v_guard_id uuid;
  v_thread public.cp_message_threads%rowtype;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    return false;
  end if;

  select * into v_thread from public.cp_message_threads where id = p_thread_id limit 1;
  if not found then
    return false;
  end if;

  if v_profile.role = 'admin' then
    return true;
  elsif v_profile.role = 'client' then
    v_client_id := coalesce(v_profile.client_id, public.cp_current_client_id());
    return v_thread.client_id = v_client_id;
  elsif v_profile.role = 'guard' then
    v_guard_id := coalesce(v_profile.guard_id, public.cp_current_guard_id());
    return v_thread.guard_id = v_guard_id;
  end if;

  return false;
end;
$$;

create or replace function public.cp_ensure_message_thread(
  p_target_role text default 'admin',
  p_target_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_target_role text := lower(coalesce(nullif(trim(p_target_role), ''), 'admin'));
  v_client_id uuid;
  v_guard_id uuid;
  v_thread public.cp_message_threads%rowtype;
  v_admin_profile_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    raise exception 'Approved profile not found.';
  end if;

  v_role := lower(coalesce(v_profile.role, ''));
  select id into v_admin_profile_id from public.profiles where role = 'admin' and coalesce(status,'active') = 'active' order by created_at asc limit 1;

  if v_role = 'admin' then
    if v_target_role = 'client' then
      if p_target_id is null then raise exception 'Select a client to message.'; end if;
      if not exists(select 1 from public.clients where id = p_target_id and coalesce(status,'active') = 'active') then
        raise exception 'Approved client not found.';
      end if;

      select * into v_thread from public.cp_message_threads where client_id = p_target_id and guard_id is null limit 1;
      if not found then
        insert into public.cp_message_threads (admin_profile_id, client_id, title, created_at, updated_at, admin_last_read_at)
        values (coalesce(v_admin_profile_id, v_profile.id), p_target_id, 'Admin / Client', now(), now(), now())
        returning * into v_thread;
      else
        update public.cp_message_threads set admin_profile_id = coalesce(admin_profile_id, v_profile.id), updated_at = now() where id = v_thread.id returning * into v_thread;
      end if;

    elsif v_target_role = 'guard' then
      if p_target_id is null then raise exception 'Select a guard to message.'; end if;
      if not exists(select 1 from public.guards where id = p_target_id and coalesce(status,'active') = 'active') then
        raise exception 'Approved guard not found.';
      end if;

      select * into v_thread from public.cp_message_threads where guard_id = p_target_id and client_id is null limit 1;
      if not found then
        insert into public.cp_message_threads (admin_profile_id, guard_id, title, created_at, updated_at, admin_last_read_at)
        values (coalesce(v_admin_profile_id, v_profile.id), p_target_id, 'Admin / Guard', now(), now(), now())
        returning * into v_thread;
      else
        update public.cp_message_threads set admin_profile_id = coalesce(admin_profile_id, v_profile.id), updated_at = now() where id = v_thread.id returning * into v_thread;
      end if;
    else
      raise exception 'Admin can start conversations with guards or clients only.';
    end if;

  elsif v_role = 'client' then
    if v_target_role <> 'admin' then raise exception 'Clients can message admin only in this build.'; end if;
    v_client_id := coalesce(v_profile.client_id, public.cp_current_client_id());
    if v_client_id is null then raise exception 'Approved client record not found.'; end if;

    select * into v_thread from public.cp_message_threads where client_id = v_client_id and guard_id is null limit 1;
    if not found then
      insert into public.cp_message_threads (admin_profile_id, client_id, title, created_at, updated_at, client_last_read_at)
      values (v_admin_profile_id, v_client_id, 'Client / Admin', now(), now(), now())
      returning * into v_thread;
    else
      update public.cp_message_threads set updated_at = now() where id = v_thread.id returning * into v_thread;
    end if;

  elsif v_role = 'guard' then
    if v_target_role <> 'admin' then raise exception 'Guards can message admin only in this build.'; end if;
    v_guard_id := coalesce(v_profile.guard_id, public.cp_current_guard_id());
    if v_guard_id is null then raise exception 'Approved guard record not found.'; end if;

    select * into v_thread from public.cp_message_threads where guard_id = v_guard_id and client_id is null limit 1;
    if not found then
      insert into public.cp_message_threads (admin_profile_id, guard_id, title, created_at, updated_at, guard_last_read_at)
      values (v_admin_profile_id, v_guard_id, 'Guard / Admin', now(), now(), now())
      returning * into v_thread;
    else
      update public.cp_message_threads set updated_at = now() where id = v_thread.id returning * into v_thread;
    end if;

  else
    raise exception 'Unknown role.';
  end if;

  return jsonb_build_object('ok', true, 'thread', row_to_json(v_thread));
end;
$$;

create or replace function public.cp_mark_message_thread_read(p_thread_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_thread public.cp_message_threads%rowtype;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then raise exception 'Approved profile not found.'; end if;
  if not public.cp_can_access_message_thread(p_thread_id) then raise exception 'You cannot open this conversation.'; end if;

  if v_profile.role = 'admin' then
    update public.cp_message_threads set admin_last_read_at = now(), updated_at = now() where id = p_thread_id returning * into v_thread;
  elsif v_profile.role = 'client' then
    update public.cp_message_threads set client_last_read_at = now(), updated_at = now() where id = p_thread_id returning * into v_thread;
  elsif v_profile.role = 'guard' then
    update public.cp_message_threads set guard_last_read_at = now(), updated_at = now() where id = p_thread_id returning * into v_thread;
  else
    raise exception 'Unknown role.';
  end if;

  return jsonb_build_object('ok', true, 'thread', row_to_json(v_thread));
end;
$$;

create or replace function public.cp_send_message(
  p_thread_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_thread public.cp_message_threads%rowtype;
  v_message public.cp_messages%rowtype;
  v_body text := trim(coalesce(p_body, ''));
  v_sender_name text;
begin
  if v_body = '' then raise exception 'Type a message before sending.'; end if;
  if length(v_body) > 2000 then raise exception 'Message is too long. Keep messages under 2000 characters.'; end if;

  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then raise exception 'Approved profile not found.'; end if;
  if not public.cp_can_access_message_thread(p_thread_id) then raise exception 'You cannot send to this conversation.'; end if;

  select * into v_thread from public.cp_message_threads where id = p_thread_id limit 1;
  if not found then raise exception 'Conversation not found.'; end if;

  v_sender_name := coalesce(nullif(trim(v_profile.display_name), ''), v_profile.email, v_profile.role, 'User');

  insert into public.cp_messages (thread_id, sender_profile_id, sender_role, sender_name, body, is_system, created_at)
  values (p_thread_id, v_profile.id, v_profile.role, v_sender_name, v_body, false, now())
  returning * into v_message;

  update public.cp_message_threads
  set last_message = left(v_body, 180),
      last_message_at = v_message.created_at,
      updated_at = now(),
      admin_last_read_at = case when v_profile.role = 'admin' then now() else admin_last_read_at end,
      client_last_read_at = case when v_profile.role = 'client' then now() else client_last_read_at end,
      guard_last_read_at = case when v_profile.role = 'guard' then now() else guard_last_read_at end
  where id = p_thread_id
  returning * into v_thread;

  if v_profile.role = 'admin' then
    if v_thread.client_id is not null then
      perform public.cp_create_notification('client', v_thread.client_id, null, null, 'New admin message', left(v_body, 160));
    elsif v_thread.guard_id is not null then
      perform public.cp_create_notification('guard', null, v_thread.guard_id, null, 'New admin message', left(v_body, 160));
    end if;
  else
    perform public.cp_create_notification('admin', null, null, null, 'New ' || v_profile.role || ' message', left(v_body, 160));
  end if;

  return jsonb_build_object('ok', true, 'message', row_to_json(v_message), 'thread', row_to_json(v_thread));
end;
$$;

create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.');
  end if;

  v_role := v_profile.role;
  v_client_id := coalesce(v_profile.client_id, public.cp_current_client_id());
  v_guard_id := coalesce(v_profile.guard_id, public.cp_current_guard_id());

  if v_role = 'admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g) order by g.created_at desc) from public.guards g), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.updated_at desc, pr.created_at desc) from public.patrol_reports pr), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.target_role = 'admin'), '[]'::jsonb),
      'patrolActivity', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.cp_patrol_activity_log a), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m where m.thread_id in (select t.id from public.cp_message_threads t)), '[]'::jsonb)
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c)) from public.clients c where c.id = v_client_id or c.auth_user_id = v_uid or lower(c.email) = v_email), '[]'::jsonb),
      'guards', coalesce((
        select jsonb_agg(row_to_json(g) order by g.updated_at desc, g.last_seen_at desc nulls last)
        from public.guards g
        where g.id in (
          select r.guard_id
          from public.patrol_requests r
          where r.client_id = v_client_id
            and r.status in ('assigned','accepted','in_progress')
            and r.guard_id is not null
        )
      ), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb),
      'proofItems', coalesce((
        select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc)
        from public.patrol_proof_items pi
        join public.patrol_reports pr on pr.request_id = pi.request_id and pr.status = 'released'
        join public.patrol_requests r on r.id = pi.request_id
        where r.client_id = v_client_id
          and coalesce(pi.report_selected, false) = true
      ), '[]'::jsonb),
      'patrolReports', coalesce((
        select jsonb_agg(row_to_json(pr) order by pr.released_at desc nulls last, pr.updated_at desc)
        from public.patrol_reports pr
        join public.patrol_requests r on r.id = pr.request_id
        where r.client_id = v_client_id
          and pr.status = 'released'
      ), '[]'::jsonb),
      'notifications', coalesce((
        select jsonb_agg(row_to_json(n) order by n.created_at desc)
        from public.cp_in_app_notifications n
        where n.target_role = 'client' and n.client_id = v_client_id
      ), '[]'::jsonb),
      'patrolActivity', coalesce((
        select jsonb_agg(row_to_json(a) order by a.created_at desc)
        from public.cp_patrol_activity_log a
        join public.patrol_requests r on r.id = a.request_id
        where r.client_id = v_client_id
      ), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t where t.client_id = v_client_id), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m where m.thread_id in (select t.id from public.cp_message_threads t where t.client_id = v_client_id)), '[]'::jsonb)
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((select jsonb_agg(row_to_json(c) order by c.created_at desc) from public.clients c where c.id in (select r.client_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'guards', coalesce((select jsonb_agg(row_to_json(g)) from public.guards g where g.id = v_guard_id or g.auth_user_id = v_uid or lower(g.email) = v_email), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select r.property_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.request_id in (select r.id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolReports', '[]'::jsonb,
      'notifications', coalesce((
        select jsonb_agg(row_to_json(n) order by n.created_at desc)
        from public.cp_in_app_notifications n
        where n.target_role = 'guard' and n.guard_id = v_guard_id
      ), '[]'::jsonb),
      'patrolActivity', coalesce((
        select jsonb_agg(row_to_json(a) order by a.created_at desc)
        from public.cp_patrol_activity_log a
        join public.patrol_requests r on r.id = a.request_id
        where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')
      ), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t where t.guard_id = v_guard_id), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m where m.thread_id in (select t.id from public.cp_message_threads t where t.guard_id = v_guard_id)), '[]'::jsonb)
    );
  else
    return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
  end if;
end;
$$;

alter table public.cp_message_threads enable row level security;
alter table public.cp_messages enable row level security;

grant execute on function public.cp_can_access_message_thread(uuid) to authenticated;
grant execute on function public.cp_ensure_message_thread(text, uuid) to authenticated;
grant execute on function public.cp_send_message(uuid, text) to authenticated;
grant execute on function public.cp_mark_message_thread_read(uuid) to authenticated;
grant execute on function public.cp_get_app_data() to authenticated;


-- ============================================================
-- Included from RUN_ONCE_V1215_DISPATCH_MESSAGING_FIX.sql
-- ============================================================

-- Co Pilot Security Patrol
-- v1.2.15 Dispatch Messaging Fix
-- Optional patch after RUN_ONCE_V1214_IN_APP_MESSAGING_CORE.sql.
-- Keeps the internal role value as 'admin' but changes visible messaging labels/titles to Dispatch.

update public.cp_message_threads
set title = replace(replace(title, 'Admin', 'Dispatch'), 'admin', 'Dispatch'),
    updated_at = now()
where title ilike '%admin%';

update public.cp_in_app_notifications
set title = replace(replace(title, 'Admin', 'Dispatch'), 'admin', 'Dispatch'),
    message = replace(replace(message, 'Admin', 'Dispatch'), 'admin', 'Dispatch')
where title ilike '%admin%' or message ilike '%admin%';

-- Marker only. No schema changes in this patch.
select 'v1.2.15 Dispatch Messaging Fix applied' as status;


-- ============================================================
-- Included from RUN_ONCE_V1216_DISPATCH_CHAT_OPEN_FIX.sql
-- ============================================================

-- Co Pilot Security Patrol
-- v1.2.16 Dispatch Chat Open Fix
-- Run once after RUN_ONCE_V1214_IN_APP_MESSAGING_CORE.sql.
-- Fixes enum app_role failures caused by treating visible "Dispatch" wording as a role value.
-- Internal role remains admin. User-facing wording remains Dispatch.

create or replace function public.cp_ensure_dispatch_message_thread(
  p_target_role text default 'admin',
  p_target_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_target_role text := lower(coalesce(nullif(trim(p_target_role), ''), 'admin'));
  v_client_id uuid;
  v_guard_id uuid;
  v_thread public.cp_message_threads%rowtype;
  v_admin_profile_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    raise exception 'Approved profile not found.';
  end if;

  -- Important: profiles.role may be an app_role enum in older databases.
  -- Always cast to text before coalescing so Postgres never tries to cast '' into app_role.
  v_role := lower(coalesce(v_profile.role::text, ''));
  v_target_role := case when v_target_role = 'dispatch' then 'admin' else v_target_role end;

  select id into v_admin_profile_id
  from public.profiles
  where role::text = 'admin' and coalesce(status::text, 'active') = 'active'
  order by created_at asc
  limit 1;

  if v_role = 'admin' then
    if v_target_role = 'client' then
      if p_target_id is null then raise exception 'Select a client to message.'; end if;
      if not exists(select 1 from public.clients where id = p_target_id and coalesce(status::text,'active') = 'active') then
        raise exception 'Approved client not found.';
      end if;

      select * into v_thread from public.cp_message_threads where client_id = p_target_id and guard_id is null limit 1;
      if not found then
        insert into public.cp_message_threads (admin_profile_id, client_id, title, created_at, updated_at, admin_last_read_at)
        values (coalesce(v_admin_profile_id, v_profile.id), p_target_id, 'Dispatch / Client', now(), now(), now())
        returning * into v_thread;
      else
        update public.cp_message_threads
        set admin_profile_id = coalesce(admin_profile_id, v_profile.id),
            title = case when coalesce(title,'') ilike '%admin%' or coalesce(title,'') = '' then 'Dispatch / Client' else title end,
            updated_at = now()
        where id = v_thread.id
        returning * into v_thread;
      end if;

    elsif v_target_role = 'guard' then
      if p_target_id is null then raise exception 'Select a guard to message.'; end if;
      if not exists(select 1 from public.guards where id = p_target_id and coalesce(status::text,'active') = 'active') then
        raise exception 'Approved guard not found.';
      end if;

      select * into v_thread from public.cp_message_threads where guard_id = p_target_id and client_id is null limit 1;
      if not found then
        insert into public.cp_message_threads (admin_profile_id, guard_id, title, created_at, updated_at, admin_last_read_at)
        values (coalesce(v_admin_profile_id, v_profile.id), p_target_id, 'Dispatch / Guard', now(), now(), now())
        returning * into v_thread;
      else
        update public.cp_message_threads
        set admin_profile_id = coalesce(admin_profile_id, v_profile.id),
            title = case when coalesce(title,'') ilike '%admin%' or coalesce(title,'') = '' then 'Dispatch / Guard' else title end,
            updated_at = now()
        where id = v_thread.id
        returning * into v_thread;
      end if;
    else
      raise exception 'Dispatch can start conversations with guards or clients only.';
    end if;

  elsif v_role = 'client' then
    if v_target_role <> 'admin' then raise exception 'Clients can message Dispatch only in this build.'; end if;
    v_client_id := coalesce(v_profile.client_id, public.cp_current_client_id());
    if v_client_id is null then raise exception 'Approved client record not found.'; end if;

    select * into v_thread from public.cp_message_threads where client_id = v_client_id and guard_id is null limit 1;
    if not found then
      insert into public.cp_message_threads (admin_profile_id, client_id, title, created_at, updated_at, client_last_read_at)
      values (v_admin_profile_id, v_client_id, 'Client / Dispatch', now(), now(), now())
      returning * into v_thread;
    else
      update public.cp_message_threads
      set title = case when coalesce(title,'') ilike '%admin%' or coalesce(title,'') = '' then 'Client / Dispatch' else title end,
          updated_at = now()
      where id = v_thread.id
      returning * into v_thread;
    end if;

  elsif v_role = 'guard' then
    if v_target_role <> 'admin' then raise exception 'Guards can message Dispatch only in this build.'; end if;
    v_guard_id := coalesce(v_profile.guard_id, public.cp_current_guard_id());
    if v_guard_id is null then raise exception 'Approved guard record not found.'; end if;

    select * into v_thread from public.cp_message_threads where guard_id = v_guard_id and client_id is null limit 1;
    if not found then
      insert into public.cp_message_threads (admin_profile_id, guard_id, title, created_at, updated_at, guard_last_read_at)
      values (v_admin_profile_id, v_guard_id, 'Guard / Dispatch', now(), now(), now())
      returning * into v_thread;
    else
      update public.cp_message_threads
      set title = case when coalesce(title,'') ilike '%admin%' or coalesce(title,'') = '' then 'Guard / Dispatch' else title end,
          updated_at = now()
      where id = v_thread.id
      returning * into v_thread;
    end if;

  else
    raise exception 'Unknown role.';
  end if;

  return jsonb_build_object('ok', true, 'thread', row_to_json(v_thread));
end;
$$;

-- Keep the old RPC name working too, in case any cached browser code calls it.
create or replace function public.cp_ensure_message_thread(
  p_target_role text default 'admin',
  p_target_id uuid default null
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.cp_ensure_dispatch_message_thread(p_target_role, p_target_id);
$$;

create or replace function public.cp_send_message(
  p_thread_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_thread public.cp_message_threads%rowtype;
  v_message public.cp_messages%rowtype;
  v_body text := trim(coalesce(p_body, ''));
  v_sender_name text;
  v_role text;
begin
  if v_body = '' then raise exception 'Type a message before sending.'; end if;
  if length(v_body) > 2000 then raise exception 'Message is too long. Keep messages under 2000 characters.'; end if;

  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(email) = v_email
  limit 1;

  if not found then raise exception 'Approved profile not found.'; end if;
  if not public.cp_can_access_message_thread(p_thread_id) then raise exception 'You cannot send to this conversation.'; end if;

  v_role := lower(coalesce(v_profile.role::text, ''));

  select * into v_thread from public.cp_message_threads where id = p_thread_id limit 1;
  if not found then raise exception 'Conversation not found.'; end if;

  v_sender_name := coalesce(nullif(trim(v_profile.display_name), ''), v_profile.email, v_role, 'User');

  insert into public.cp_messages (thread_id, sender_profile_id, sender_role, sender_name, body, is_system, created_at)
  values (p_thread_id, v_profile.id, v_role, v_sender_name, v_body, false, now())
  returning * into v_message;

  update public.cp_message_threads
  set last_message = left(v_body, 180),
      last_message_at = v_message.created_at,
      updated_at = now(),
      admin_last_read_at = case when v_role = 'admin' then now() else admin_last_read_at end,
      client_last_read_at = case when v_role = 'client' then now() else client_last_read_at end,
      guard_last_read_at = case when v_role = 'guard' then now() else guard_last_read_at end
  where id = p_thread_id
  returning * into v_thread;

  if v_role = 'admin' then
    if v_thread.client_id is not null then
      perform public.cp_create_notification('client', v_thread.client_id, null, null, 'New Dispatch message', left(v_body, 160));
    elsif v_thread.guard_id is not null then
      perform public.cp_create_notification('guard', null, v_thread.guard_id, null, 'New Dispatch message', left(v_body, 160));
    end if;
  elsif v_role in ('client','guard') then
    perform public.cp_create_notification('admin', null, null, null, 'New ' || v_role || ' message', left(v_body, 160));
  end if;

  return jsonb_build_object('ok', true, 'message', row_to_json(v_message), 'thread', row_to_json(v_thread));
end;
$$;

update public.cp_message_threads
set title = replace(replace(title, 'Admin', 'Dispatch'), 'admin', 'Dispatch'),
    updated_at = now()
where title ilike '%admin%';

update public.cp_in_app_notifications
set title = replace(replace(title, 'Admin', 'Dispatch'), 'admin', 'Dispatch'),
    message = replace(replace(message, 'Admin', 'Dispatch'), 'admin', 'Dispatch')
where title ilike '%admin%' or message ilike '%admin%';

grant execute on function public.cp_ensure_dispatch_message_thread(text, uuid) to authenticated;
grant execute on function public.cp_ensure_message_thread(text, uuid) to authenticated;
grant execute on function public.cp_send_message(uuid, text) to authenticated;

select 'v1.2.16 Dispatch Chat Open Fix applied' as status;


-- ============================================================
-- Included from RUN_ONCE_V1217_ORGANIZED_DISPATCH_MESSAGE_INBOX.sql
-- ============================================================

-- v1.2.17 Organized Dispatch Message Inbox
-- No schema change required if RUN_ONCE_V1214_IN_APP_MESSAGING_CORE.sql and
-- RUN_ONCE_V1216_DISPATCH_CHAT_OPEN_FIX.sql were already run.
-- This file is intentionally safe to run as a version marker.
select 'v1.2.17 organized dispatch message inbox installed - no schema changes required' as status;


-- ============================================================
-- Included from RUN_ONCE_V1218_MAP_ADDRESS_POPUPS.sql
-- ============================================================

-- v1.2.18 Map Address Popups
-- No schema changes required.
-- This build updates front-end map marker behavior only:
-- - property red pulse popup shows client + property + address
-- - guard blue pulse popup reverse-geocodes GPS to a street address on click
select 'v1.2.18 map address popups marker complete - no SQL changes required' as status;


-- ============================================================
-- Included from RUN_ONCE_V1219_PROFILE_PHOTOS_SETTINGS.sql
-- ============================================================

-- v1.2.19 PROFILE PHOTOS + SETTINGS
-- Run once in Supabase SQL Editor after previous v1.2.x SQL files.
-- Adds device-uploaded profile photos and account settings support.
-- No invite codes. No claim codes. No pricing. No Edge Functions.

create extension if not exists pgcrypto;

alter table public.profiles add column if not exists avatar_url text default '';
alter table public.clients add column if not exists avatar_url text default '';
alter table public.guards add column if not exists avatar_url text default '';

-- Public profile photo bucket used only for displaying images uploaded from the user's device.
-- The app does not show any URL input fields to users.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos',
  'profile-photos',
  true,
  8388608,
  array['image/jpeg','image/jpg','image/png','image/webp','image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "cp profile photos public read" on storage.objects;
drop policy if exists "cp profile photos authenticated upload" on storage.objects;
drop policy if exists "cp profile photos owner update" on storage.objects;
drop policy if exists "cp profile photos owner delete" on storage.objects;

create policy "cp profile photos public read"
on storage.objects
for select
to public
using (bucket_id = 'profile-photos');

create policy "cp profile photos authenticated upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'profile-photos');

create policy "cp profile photos owner update"
on storage.objects
for update
to authenticated
using (bucket_id = 'profile-photos' and owner = auth.uid())
with check (bucket_id = 'profile-photos' and owner = auth.uid());

create policy "cp profile photos owner delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'profile-photos' and owner = auth.uid());

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

create or replace function public.cp_update_my_profile(
  p_display_name text default null,
  p_avatar_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_name text;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid
     or id = v_uid
     or lower(coalesce(email,'')) = v_email
  limit 1;

  if not found then
    raise exception 'No approved profile found for this login.';
  end if;

  v_name := coalesce(nullif(trim(p_display_name), ''), v_profile.display_name, v_profile.email, 'User');

  update public.profiles
  set display_name = v_name,
      avatar_url = coalesce(nullif(trim(coalesce(p_avatar_url, '')), ''), avatar_url, ''),
      updated_at = now()
  where id = v_profile.id
  returning * into v_profile;

  if v_profile.role = 'guard' and v_profile.guard_id is not null then
    update public.guards
    set name = v_profile.display_name,
        avatar_url = coalesce(v_profile.avatar_url, ''),
        updated_at = now()
    where id = v_profile.guard_id;
  elsif v_profile.role = 'client' and v_profile.client_id is not null then
    update public.clients
    set name = v_profile.display_name,
        avatar_url = coalesce(v_profile.avatar_url, ''),
        updated_at = now()
    where id = v_profile.client_id;
  end if;

  return jsonb_build_object('ok', true, 'profile', row_to_json(v_profile));
end;
$$;

grant execute on function public.cp_update_my_profile(text,text) to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V1220_PROPERTY_PHOTOS_MAP_IDENTITY_CARDS.sql
-- ============================================================

-- v1.2.20 PROPERTY PHOTOS + MAP IDENTITY CARDS
-- Run once in Supabase SQL Editor after v1.2.19 SQL.
-- Adds device-uploaded property photo storage support.
-- No visible photo/video URL fields are added to the app.
-- No pricing. No SMS/email. No invite codes. No claim codes. No Edge Functions.

create extension if not exists pgcrypto;

alter table public.properties add column if not exists photo_url text default '';

-- Public property photo bucket used only for displaying images uploaded from a user's device.
-- Users never paste or see photo URLs inside the app.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'property-photos',
  'property-photos',
  true,
  10485760,
  array['image/jpeg','image/jpg','image/png','image/webp','image/gif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "cp property photos public read" on storage.objects;
drop policy if exists "cp property photos authenticated upload" on storage.objects;
drop policy if exists "cp property photos owner update" on storage.objects;
drop policy if exists "cp property photos owner delete" on storage.objects;

create policy "cp property photos public read"
on storage.objects
for select
to public
using (bucket_id = 'property-photos');

create policy "cp property photos authenticated upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'property-photos');

create policy "cp property photos owner update"
on storage.objects
for update
to authenticated
using (bucket_id = 'property-photos' and owner = auth.uid())
with check (bucket_id = 'property-photos' and owner = auth.uid());

create policy "cp property photos owner delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'property-photos' and owner = auth.uid());

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V1221_ADMIN_GUARD_PHOTO_PROPERTY_CARD_FIX.sql
-- ============================================================

-- v1.2.21 ADMIN GUARD PHOTO + PROPERTY CARD LAYOUT FIX
-- Run once after v1.2.20 SQL if Dispatch/Admin still sees default guard icons on map.
-- No new tables. No pricing. No SMS/email. No invite codes. No claim codes.

alter table if exists public.profiles add column if not exists avatar_url text default '';
alter table if exists public.guards add column if not exists avatar_url text default '';
alter table if exists public.clients add column if not exists avatar_url text default '';

-- Backfill guard/client avatar URLs from uploaded profile photos so Dispatch map popups
-- can use the same profile photo that the guard/client sees in their own login.
update public.guards g
set avatar_url = coalesce(nullif(g.avatar_url, ''), nullif(p.avatar_url, ''), '')
from public.profiles p
where (p.role = 'guard')
  and (p.guard_id = g.id or p.auth_user_id = g.auth_user_id or lower(coalesce(p.email,'')) = lower(coalesce(g.email,'')))
  and coalesce(g.avatar_url, '') = ''
  and coalesce(p.avatar_url, '') <> '';

update public.clients c
set avatar_url = coalesce(nullif(c.avatar_url, ''), nullif(p.avatar_url, ''), '')
from public.profiles p
where (p.role = 'client')
  and (p.client_id = c.id or p.auth_user_id = c.auth_user_id or lower(coalesce(p.email,'')) = lower(coalesce(c.email,'')))
  and coalesce(c.avatar_url, '') = ''
  and coalesce(p.avatar_url, '') <> '';

-- Harden future profile saves so uploaded photos always sync to the visible guard/client records.
create or replace function public.cp_update_my_profile(
  p_display_name text default null,
  p_avatar_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_name text;
  v_avatar text;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid
     or id = v_uid
     or lower(coalesce(email,'')) = v_email
  limit 1;

  if not found then
    raise exception 'No approved profile found for this login.';
  end if;

  v_name := coalesce(nullif(trim(p_display_name), ''), v_profile.display_name, v_profile.email, 'User');
  v_avatar := coalesce(nullif(trim(coalesce(p_avatar_url, '')), ''), v_profile.avatar_url, '');

  update public.profiles
  set display_name = v_name,
      avatar_url = v_avatar,
      updated_at = now()
  where id = v_profile.id
  returning * into v_profile;

  if v_profile.role = 'guard' then
    update public.guards
    set name = v_profile.display_name,
        avatar_url = coalesce(v_profile.avatar_url, ''),
        updated_at = now()
    where id = v_profile.guard_id
       or auth_user_id = v_profile.auth_user_id
       or lower(coalesce(email,'')) = lower(coalesce(v_profile.email,''));
  elsif v_profile.role = 'client' then
    update public.clients
    set name = v_profile.display_name,
        avatar_url = coalesce(v_profile.avatar_url, ''),
        updated_at = now()
    where id = v_profile.client_id
       or auth_user_id = v_profile.auth_user_id
       or lower(coalesce(email,'')) = lower(coalesce(v_profile.email,''));
  end if;

  return jsonb_build_object('ok', true, 'profile', row_to_json(v_profile));
end;
$$;

grant execute on function public.cp_update_my_profile(text,text) to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- Included from RUN_ONCE_V1222_ADMIN_PHOTO_DATA_CARD_FORCE.sql
-- ============================================================

-- v1.2.22 ADMIN PHOTO DATA + PROPERTY CARD FORCE
-- Run once after v1.2.21B if the new repo loads the latest badge but Dispatch/Admin still sees default guard avatars.
-- This fixes the real data path: Dispatch/Admin must receive guard/client profile photos through cp_get_app_data.
-- No pricing. No SMS/email. No invite codes. No claim codes. No admin-created passwords.

alter table if exists public.profiles add column if not exists avatar_url text default '';
alter table if exists public.guards add column if not exists avatar_url text default '';
alter table if exists public.clients add column if not exists avatar_url text default '';
alter table if exists public.properties add column if not exists photo_url text default '';

-- Backfill visible guard/client rows from profile photos when possible.
update public.guards g
set avatar_url = coalesce(nullif(g.avatar_url, ''), nullif(p.avatar_url, ''), '')
from public.profiles p
where p.role::text = 'guard'
  and (
    p.guard_id = g.id
    or p.auth_user_id = g.auth_user_id
    or lower(coalesce(p.email,'')) = lower(coalesce(g.email,''))
  )
  and coalesce(g.avatar_url, '') = ''
  and coalesce(p.avatar_url, '') <> '';

update public.clients c
set avatar_url = coalesce(nullif(c.avatar_url, ''), nullif(p.avatar_url, ''), '')
from public.profiles p
where p.role::text = 'client'
  and (
    p.client_id = c.id
    or p.auth_user_id = c.auth_user_id
    or lower(coalesce(p.email,'')) = lower(coalesce(c.email,''))
  )
  and coalesce(c.avatar_url, '') = ''
  and coalesce(p.avatar_url, '') <> '';

-- Harden profile saves so all future device-uploaded profile photos sync into the visible role records too.
create or replace function public.cp_update_my_profile(
  p_display_name text default null,
  p_avatar_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_name text;
  v_avatar text;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid
     or id = v_uid
     or lower(coalesce(email,'')) = v_email
  limit 1;

  if not found then
    raise exception 'No approved profile found for this login.';
  end if;

  v_name := coalesce(nullif(trim(p_display_name), ''), v_profile.display_name, v_profile.email, 'User');
  v_avatar := coalesce(nullif(trim(coalesce(p_avatar_url, '')), ''), v_profile.avatar_url, '');

  update public.profiles
  set display_name = v_name,
      avatar_url = v_avatar,
      updated_at = now()
  where id = v_profile.id
  returning * into v_profile;

  if v_profile.role::text = 'guard' then
    update public.guards
    set name = v_profile.display_name,
        avatar_url = coalesce(v_profile.avatar_url, ''),
        updated_at = now()
    where id = v_profile.guard_id
       or auth_user_id = v_profile.auth_user_id
       or lower(coalesce(email,'')) = lower(coalesce(v_profile.email,''));
  elsif v_profile.role::text = 'client' then
    update public.clients
    set name = v_profile.display_name,
        avatar_url = coalesce(v_profile.avatar_url, ''),
        updated_at = now()
    where id = v_profile.client_id
       or auth_user_id = v_profile.auth_user_id
       or lower(coalesce(email,'')) = lower(coalesce(v_profile.email,''));
  end if;

  return jsonb_build_object('ok', true, 'profile', row_to_json(v_profile));
end;
$$;

grant execute on function public.cp_update_my_profile(text,text) to authenticated;

-- Main repair: enrich guards/clients returned to Dispatch/Admin and active Client views with profile_avatar_url.
create or replace function public.cp_get_app_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_profile public.profiles%rowtype;
  v_role text;
  v_client_id uuid;
  v_guard_id uuid;
begin
  select * into v_profile
  from public.profiles
  where auth_user_id = v_uid or id = v_uid or lower(coalesce(email,'')) = v_email
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'profile', null, 'message', 'No approved profile for this login.');
  end if;

  v_role := v_profile.role::text;
  v_client_id := coalesce(v_profile.client_id, public.cp_current_client_id());
  v_guard_id := coalesce(v_profile.guard_id, public.cp_current_guard_id());

  if v_role = 'admin' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((
        select jsonb_agg((to_jsonb(c) || jsonb_build_object(
          'avatar_url', coalesce(nullif(c.avatar_url,''), nullif(cp.avatar_url,''), ''),
          'profile_avatar_url', coalesce(nullif(cp.avatar_url,''), '')
        )) order by c.created_at desc)
        from public.clients c
        left join lateral (
          select p.avatar_url
          from public.profiles p
          where p.role::text = 'client'
            and (p.client_id = c.id or p.auth_user_id = c.auth_user_id or lower(coalesce(p.email,'')) = lower(coalesce(c.email,'')))
          order by p.updated_at desc nulls last, p.created_at desc nulls last
          limit 1
        ) cp on true
      ), '[]'::jsonb),
      'guards', coalesce((
        select jsonb_agg((to_jsonb(g) || jsonb_build_object(
          'avatar_url', coalesce(nullif(g.avatar_url,''), nullif(gp.avatar_url,''), ''),
          'profile_avatar_url', coalesce(nullif(gp.avatar_url,''), '')
        )) order by g.created_at desc)
        from public.guards g
        left join lateral (
          select p.avatar_url
          from public.profiles p
          where p.role::text = 'guard'
            and (p.guard_id = g.id or p.auth_user_id = g.auth_user_id or lower(coalesce(p.email,'')) = lower(coalesce(g.email,'')))
          order by p.updated_at desc nulls last, p.created_at desc nulls last
          limit 1
        ) gp on true
      ), '[]'::jsonb),
      'guardSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_guard_signups s), '[]'::jsonb),
      'clientSignups', coalesce((select jsonb_agg(row_to_json(s) order by s.created_at desc) from public.pending_client_signups s), '[]'::jsonb),
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi), '[]'::jsonb),
      'patrolReports', coalesce((select jsonb_agg(row_to_json(pr) order by pr.updated_at desc, pr.created_at desc) from public.patrol_reports pr), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.target_role = 'admin'), '[]'::jsonb),
      'patrolActivity', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from public.cp_patrol_activity_log a), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m where m.thread_id in (select t.id from public.cp_message_threads t)), '[]'::jsonb)
    );
  elsif v_role = 'client' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((
        select jsonb_agg((to_jsonb(c) || jsonb_build_object(
          'avatar_url', coalesce(nullif(c.avatar_url,''), nullif(cp.avatar_url,''), ''),
          'profile_avatar_url', coalesce(nullif(cp.avatar_url,''), '')
        )))
        from public.clients c
        left join lateral (
          select p.avatar_url
          from public.profiles p
          where p.role::text = 'client'
            and (p.client_id = c.id or p.auth_user_id = c.auth_user_id or lower(coalesce(p.email,'')) = lower(coalesce(c.email,'')))
          order by p.updated_at desc nulls last, p.created_at desc nulls last
          limit 1
        ) cp on true
        where c.id = v_client_id or c.auth_user_id = v_uid or lower(coalesce(c.email,'')) = v_email
      ), '[]'::jsonb),
      'guards', coalesce((
        select jsonb_agg((to_jsonb(g) || jsonb_build_object(
          'avatar_url', coalesce(nullif(g.avatar_url,''), nullif(gp.avatar_url,''), ''),
          'profile_avatar_url', coalesce(nullif(gp.avatar_url,''), '')
        )) order by g.updated_at desc, g.last_seen_at desc nulls last)
        from public.guards g
        left join lateral (
          select p.avatar_url
          from public.profiles p
          where p.role::text = 'guard'
            and (p.guard_id = g.id or p.auth_user_id = g.auth_user_id or lower(coalesce(p.email,'')) = lower(coalesce(g.email,'')))
          order by p.updated_at desc nulls last, p.created_at desc nulls last
          limit 1
        ) gp on true
        where g.id in (
          select r.guard_id
          from public.patrol_requests r
          where r.client_id = v_client_id
            and r.status in ('assigned','accepted','in_progress')
            and r.guard_id is not null
        )
      ), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.client_id = v_client_id), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.client_id = v_client_id), '[]'::jsonb),
      'proofItems', coalesce((
        select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc)
        from public.patrol_proof_items pi
        join public.patrol_reports pr on pr.request_id = pi.request_id and pr.status = 'released'
        join public.patrol_requests r on r.id = pi.request_id
        where r.client_id = v_client_id and coalesce(pi.report_selected, false) = true
      ), '[]'::jsonb),
      'patrolReports', coalesce((
        select jsonb_agg(row_to_json(pr) order by pr.released_at desc nulls last, pr.updated_at desc)
        from public.patrol_reports pr
        join public.patrol_requests r on r.id = pr.request_id
        where r.client_id = v_client_id and pr.status = 'released'
      ), '[]'::jsonb),
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.target_role = 'client' and n.client_id = v_client_id), '[]'::jsonb),
      'patrolActivity', coalesce((
        select jsonb_agg(row_to_json(a) order by a.created_at desc)
        from public.cp_patrol_activity_log a
        join public.patrol_requests r on r.id = a.request_id
        where r.client_id = v_client_id
      ), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t where t.client_id = v_client_id), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m where m.thread_id in (select t.id from public.cp_message_threads t where t.client_id = v_client_id)), '[]'::jsonb)
    );
  elsif v_role = 'guard' then
    return jsonb_build_object(
      'ok', true,
      'profile', row_to_json(v_profile),
      'settings', coalesce((select jsonb_agg(row_to_json(s)) from public.business_settings s), '[]'::jsonb),
      'clients', coalesce((
        select jsonb_agg((to_jsonb(c) || jsonb_build_object(
          'avatar_url', coalesce(nullif(c.avatar_url,''), nullif(cp.avatar_url,''), ''),
          'profile_avatar_url', coalesce(nullif(cp.avatar_url,''), '')
        )) order by c.created_at desc)
        from public.clients c
        left join lateral (
          select p.avatar_url
          from public.profiles p
          where p.role::text = 'client'
            and (p.client_id = c.id or p.auth_user_id = c.auth_user_id or lower(coalesce(p.email,'')) = lower(coalesce(c.email,'')))
          order by p.updated_at desc nulls last, p.created_at desc nulls last
          limit 1
        ) cp on true
        where c.id in (select r.client_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))
      ), '[]'::jsonb),
      'guards', coalesce((
        select jsonb_agg((to_jsonb(g) || jsonb_build_object(
          'avatar_url', coalesce(nullif(g.avatar_url,''), nullif(gp.avatar_url,''), ''),
          'profile_avatar_url', coalesce(nullif(gp.avatar_url,''), '')
        )))
        from public.guards g
        left join lateral (
          select p.avatar_url
          from public.profiles p
          where p.role::text = 'guard'
            and (p.guard_id = g.id or p.auth_user_id = g.auth_user_id or lower(coalesce(p.email,'')) = lower(coalesce(g.email,'')))
          order by p.updated_at desc nulls last, p.created_at desc nulls last
          limit 1
        ) gp on true
        where g.id = v_guard_id or g.auth_user_id = v_uid or lower(coalesce(g.email,'')) = v_email
      ), '[]'::jsonb),
      'guardSignups', '[]'::jsonb,
      'clientSignups', '[]'::jsonb,
      'properties', coalesce((select jsonb_agg(row_to_json(p) order by p.created_at desc) from public.properties p where p.id in (select r.property_id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolRequests', coalesce((select jsonb_agg(row_to_json(r) order by r.updated_at desc, r.created_at desc) from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')), '[]'::jsonb),
      'proofItems', coalesce((select jsonb_agg(row_to_json(pi) order by pi.uploaded_at desc, pi.created_at desc) from public.patrol_proof_items pi where pi.request_id in (select r.id from public.patrol_requests r where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed'))), '[]'::jsonb),
      'patrolReports', '[]'::jsonb,
      'notifications', coalesce((select jsonb_agg(row_to_json(n) order by n.created_at desc) from public.cp_in_app_notifications n where n.target_role = 'guard' and n.guard_id = v_guard_id), '[]'::jsonb),
      'patrolActivity', coalesce((
        select jsonb_agg(row_to_json(a) order by a.created_at desc)
        from public.cp_patrol_activity_log a
        join public.patrol_requests r on r.id = a.request_id
        where r.guard_id = v_guard_id and r.status in ('assigned','accepted','in_progress','completed')
      ), '[]'::jsonb),
      'messageThreads', coalesce((select jsonb_agg(row_to_json(t) order by t.updated_at desc, t.created_at desc) from public.cp_message_threads t where t.guard_id = v_guard_id), '[]'::jsonb),
      'messages', coalesce((select jsonb_agg(row_to_json(m) order by m.created_at asc) from public.cp_messages m where m.thread_id in (select t.id from public.cp_message_threads t where t.guard_id = v_guard_id)), '[]'::jsonb)
    );
  else
    return jsonb_build_object('ok', false, 'profile', row_to_json(v_profile), 'message', 'Unknown role.');
  end if;
end;
$$;

grant execute on function public.cp_get_app_data() to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
-- v1.3.0 final baseline marker / schema reload
-- ============================================================

notify pgrst, 'reload schema';

select 'v1.3.0 clean consolidated baseline applied' as status;



-- ============================================================
-- v1.3.4 Completed Patrol Lock
-- Source: RUN_ONCE_V134_COMPLETED_PATROL_LOCK.sql
-- ============================================================

-- Co Pilot Security Patrol v1.3.4
-- Completed Patrol Lock
-- Run once in Supabase SQL Editor after v1.3.0 baseline SQL.
-- Purpose: prevent guard proof uploads after a patrol is marked completed.

create or replace function public.cp_guard_register_patrol_proof(
  p_request_id uuid,
  p_bucket_id text default 'patrol-proof',
  p_object_path text default '',
  p_file_name text default '',
  p_file_type text default '',
  p_file_size bigint default 0,
  p_public_url text default '',
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guard_id uuid := public.cp_current_guard_id();
  v_guard public.guards%rowtype;
  v_request public.patrol_requests%rowtype;
  v_proof public.patrol_proof_items%rowtype;
  v_kind text := lower(coalesce(p_file_type, ''));
begin
  if v_guard_id is null then
    raise exception 'Approved guard record not found.';
  end if;

  select * into v_guard from public.guards where id = v_guard_id limit 1;

  if p_request_id is null then
    raise exception 'Patrol request is required.';
  end if;

  select * into v_request
  from public.patrol_requests
  where id = p_request_id
    and guard_id = v_guard_id
  limit 1;

  if not found then
    raise exception 'This patrol request is not assigned to you.';
  end if;

  if coalesce(v_request.status, '') = 'completed' then
    raise exception 'This patrol is completed and locked. Only Dispatch can modify completed patrol records.';
  end if;

  if coalesce(v_request.status, '') not in ('accepted','in_progress') then
    raise exception 'Accept or start the patrol before uploading proof.';
  end if;

  if coalesce(p_bucket_id, '') <> 'patrol-proof' then
    raise exception 'Invalid proof storage bucket.';
  end if;

  if coalesce(p_object_path, '') = '' or p_object_path not like (p_request_id::text || '/%') then
    raise exception 'Invalid proof storage path.';
  end if;

  if not (v_kind like 'image/%' or v_kind like 'video/%') then
    raise exception 'Only photo or video proof files are allowed.';
  end if;

  insert into public.patrol_proof_items (
    id, request_id, guard_id, bucket_id, object_path, file_name, file_type,
    file_size, public_url, note, report_selected, uploaded_at, created_at, updated_at
  ) values (
    gen_random_uuid(), p_request_id, v_guard_id, 'patrol-proof', p_object_path,
    coalesce(p_file_name, ''), coalesce(p_file_type, ''), coalesce(p_file_size, 0),
    coalesce(p_public_url, ''), coalesce(p_note, ''), false, now(), now(), now()
  )
  on conflict (bucket_id, object_path) do update
  set file_name = excluded.file_name,
      file_type = excluded.file_type,
      file_size = excluded.file_size,
      public_url = excluded.public_url,
      note = excluded.note,
      updated_at = now()
  returning * into v_proof;

  perform public.cp_add_patrol_activity(
    p_request_id, 'guard', v_guard_id, coalesce(v_guard.name, 'Guard'), 'proof_uploaded',
    'Guard uploaded proof',
    coalesce(nullif(trim(p_note), ''), coalesce(p_file_name, 'Proof file uploaded'))
  );

  perform public.cp_create_notification(
    'admin', v_request.client_id, v_guard_id, p_request_id,
    'Proof uploaded',
    coalesce(v_guard.name, 'Guard') || ' uploaded patrol proof.'
  );

  return jsonb_build_object('ok', true, 'proof', row_to_json(v_proof));
end;
$$;

grant execute on function public.cp_guard_register_patrol_proof(uuid, text, text, text, text, bigint, text, text) to authenticated;



-- ============================================================
-- v1.3.5 Scheduled / Vacation / Recurring Patrols
-- Source: RUN_ONCE_V135_SCHEDULED_RECURRING_PATROLS.sql
-- ============================================================

-- v1.3.5 SCHEDULED / VACATION / RECURRING PATROLS
-- Run once in Supabase SQL Editor after v1.3.4 completed patrol lock SQL.
-- Adds scheduling fields to patrol requests and updates the client request RPC.
-- No pricing. No SMS/email. No invite codes. No claim codes. No Edge Functions.

create extension if not exists pgcrypto;

alter table public.patrol_requests add column if not exists schedule_type text default 'on_demand';
alter table public.patrol_requests add column if not exists scheduled_for timestamptz;
alter table public.patrol_requests add column if not exists schedule_start_date date;
alter table public.patrol_requests add column if not exists schedule_end_date date;
alter table public.patrol_requests add column if not exists preferred_time_window text default '';
alter table public.patrol_requests add column if not exists recurrence_pattern text default '';
alter table public.patrol_requests add column if not exists recurrence_days text default '';
alter table public.patrol_requests add column if not exists schedule_notes text default '';

update public.patrol_requests
set schedule_type = coalesce(nullif(trim(schedule_type), ''), 'on_demand'),
    preferred_time_window = coalesce(preferred_time_window, ''),
    recurrence_pattern = coalesce(recurrence_pattern, ''),
    recurrence_days = coalesce(recurrence_days, ''),
    schedule_notes = coalesce(schedule_notes, '')
where schedule_type is null
   or trim(schedule_type) = ''
   or preferred_time_window is null
   or recurrence_pattern is null
   or recurrence_days is null
   or schedule_notes is null;

create index if not exists patrol_requests_schedule_type_idx on public.patrol_requests(schedule_type);
create index if not exists patrol_requests_scheduled_for_idx on public.patrol_requests(scheduled_for);
create index if not exists patrol_requests_schedule_start_date_idx on public.patrol_requests(schedule_start_date);
create index if not exists patrol_requests_schedule_end_date_idx on public.patrol_requests(schedule_end_date);

create or replace function public.cp_current_uid()
returns uuid
language sql
stable
as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'sub'), ''),
    ''
  ), '')::uuid;
$$;

create or replace function public.cp_current_email()
returns text
language sql
stable
as $$
  select lower(coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'email'), ''),
    ''
  ));
$$;

drop function if exists public.cp_submit_patrol_request(uuid, text, text);
drop function if exists public.cp_submit_patrol_request(uuid, text, text, text, text);
drop function if exists public.cp_submit_patrol_request(uuid, text, text, text, text, text, text, text, text, text, text, text, text);

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
set search_path = public
as $$
declare
  v_uid uuid := public.cp_current_uid();
  v_email text := public.cp_current_email();
  v_client public.clients%rowtype;
  v_property public.properties%rowtype;
  v_request public.patrol_requests%rowtype;
  v_priority text := lower(coalesce(nullif(trim(p_priority), ''), 'normal'));
  v_patrol_type text := lower(coalesce(nullif(trim(p_patrol_type), ''), 'standard'));
  v_proof_preference text := lower(coalesce(nullif(trim(p_proof_preference), ''), 'photo'));
  v_schedule_type text := lower(coalesce(nullif(trim(p_schedule_type), ''), 'on_demand'));
  v_recurrence_pattern text := lower(coalesce(nullif(trim(p_recurrence_pattern), ''), ''));
  v_scheduled_for timestamptz := null;
  v_schedule_start_date date := null;
  v_schedule_end_date date := null;
begin
  if p_property_id is null then
    raise exception 'Select a saved property before requesting patrol.';
  end if;

  select * into v_client
  from public.clients
  where auth_user_id = v_uid or lower(email) = v_email
  limit 1;

  if not found then
    raise exception 'Approved client record not found.';
  end if;

  select * into v_property
  from public.properties
  where id = p_property_id and client_id = v_client.id
  limit 1;

  if not found then
    raise exception 'You can only request patrol for your own saved property.';
  end if;

  if v_priority not in ('normal', 'high', 'urgent') then
    v_priority := 'normal';
  end if;

  if v_patrol_type not in ('standard', 'urgent', 'vacation_watch', 'suspicious_activity', 'alarm_response', 'custom') then
    v_patrol_type := 'standard';
  end if;

  if v_proof_preference not in ('photo', 'video', 'photo_video', 'none') then
    v_proof_preference := 'photo';
  end if;

  if v_schedule_type not in ('on_demand', 'scheduled', 'vacation_watch', 'recurring') then
    v_schedule_type := 'on_demand';
  end if;

  if v_recurrence_pattern not in ('', 'daily', 'weekly', 'custom_days') then
    v_recurrence_pattern := '';
  end if;

  if nullif(trim(coalesce(p_scheduled_for, '')), '') is not null then
    begin
      v_scheduled_for := p_scheduled_for::timestamptz;
    exception when others then
      raise exception 'Scheduled date/time is invalid.';
    end;
  end if;

  if nullif(trim(coalesce(p_schedule_start_date, '')), '') is not null then
    begin
      v_schedule_start_date := p_schedule_start_date::date;
    exception when others then
      raise exception 'Schedule start date is invalid.';
    end;
  end if;

  if nullif(trim(coalesce(p_schedule_end_date, '')), '') is not null then
    begin
      v_schedule_end_date := p_schedule_end_date::date;
    exception when others then
      raise exception 'Schedule end date is invalid.';
    end;
  end if;

  if v_schedule_end_date is not null and v_schedule_start_date is not null and v_schedule_end_date < v_schedule_start_date then
    raise exception 'Schedule end date cannot be before start date.';
  end if;

  if v_schedule_type = 'scheduled' and v_scheduled_for is null then
    raise exception 'Choose a scheduled date and time for a future patrol.';
  end if;

  if v_schedule_type = 'vacation_watch' and (v_schedule_start_date is null or v_schedule_end_date is null) then
    raise exception 'Vacation watch requires a start date and end date.';
  end if;

  if v_schedule_type = 'recurring' and (v_schedule_start_date is null or v_recurrence_pattern = '') then
    raise exception 'Recurring patrols require a start date and recurring pattern.';
  end if;

  if v_schedule_type = 'on_demand' then
    v_scheduled_for := null;
    v_schedule_start_date := null;
    v_schedule_end_date := null;
    v_recurrence_pattern := '';
  end if;

  insert into public.patrol_requests (
    id, client_id, property_id, guard_id, status, priority, instructions,
    patrol_type, proof_preference,
    schedule_type, scheduled_for, schedule_start_date, schedule_end_date,
    preferred_time_window, recurrence_pattern, recurrence_days, schedule_notes,
    requested_at, assigned_at, accepted_at, started_at, completed_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_client.id, v_property.id, null, 'pending_dispatch', v_priority,
    coalesce(p_instructions, ''), v_patrol_type, v_proof_preference,
    v_schedule_type, v_scheduled_for, v_schedule_start_date, v_schedule_end_date,
    coalesce(p_preferred_time_window, ''), v_recurrence_pattern, coalesce(p_recurrence_days, ''), coalesce(p_schedule_notes, ''),
    now(), null, null, null, null, now(), now()
  ) returning * into v_request;

  return jsonb_build_object('ok', true, 'request', row_to_json(v_request));
end;
$$;

grant usage on schema public to anon, authenticated;
grant execute on function public.cp_submit_patrol_request(uuid, text, text, text, text, text, text, text, text, text, text, text, text) to authenticated;

notify pgrst, 'reload schema';



-- ============================================================
-- v1.3.8.3 Optional Marker / No Schema Change
-- Source: RUN_ONCE_V1383_OPS_BOARD_NAV_FILTER_SAFE_FIX.sql
-- ============================================================

-- v1.3.8.3 ops board navigation/filter safe fix
-- No schema changes required for this build.

