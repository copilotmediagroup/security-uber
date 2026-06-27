-- Co Pilot Security Marketplace v4.0.17
-- Consolidated SQL installer / patch bundle
-- Use this only if the target Supabase project needs the full marketplace foundation and patches.
-- If your Supabase already has v4.0.0-v4.0.17 SQL applied, you do not need to rerun this.
-- Order preserved from original package.


-- =====================================================================
-- BEGIN: RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql
-- =====================================================================
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


-- =====================================================================
-- END: RUN_IF_NEEDED_CONSOLIDATED_SQL_V1383.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql
-- =====================================================================
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

-- =====================================================================
-- END: RUN_AFTER_BASE_MARKETPLACE_DATA_FOUNDATION_V400.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V401_AGENCY_JOB_BOARD.sql
-- =====================================================================
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

-- =====================================================================
-- END: RUN_AFTER_V401_AGENCY_JOB_BOARD.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql
-- =====================================================================
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

-- =====================================================================
-- END: RUN_AFTER_V402_CLIENT_APPROVAL_CENTER.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql
-- =====================================================================
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

-- =====================================================================
-- END: RUN_AFTER_V403_AGENCY_DISPATCH_CLIENT_LOCATION.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V404_MARKETPLACE_ROLE_CLEANUP.sql
-- =====================================================================
-- Co Pilot Security Marketplace v4.0.4
-- MARKETPLACE ROLE CLEANUP
-- Run this after v4.0.3 SQL.
-- Purpose: remove old v3 Legacy Dispatch semantics from the marketplace database.

begin;

alter table if exists public.profiles
  add column if not exists marketplace_role text;

-- In the v4 marketplace, old v3 admin/dispatch accounts are treated as Platform Admin.
update public.profiles
set marketplace_role = 'platform_admin'
where lower(coalesce(marketplace_role, role, '')) in ('admin', 'dispatch', 'legacy_dispatch', 'legacy-dispatch');

-- Normalize the visible role where the project already supports platform_admin.
-- If a future environment has a restrictive role check, this statement should be the only one to review.
update public.profiles
set role = 'platform_admin'
where lower(coalesce(role, '')) in ('admin', 'dispatch', 'legacy_dispatch', 'legacy-dispatch')
  and lower(coalesce(marketplace_role, '')) = 'platform_admin';

-- Touch updated_at only when the column exists.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'updated_at'
  ) then
    update public.profiles
    set updated_at = now()
    where lower(coalesce(marketplace_role, '')) = 'platform_admin';
  end if;
end $$;

-- Tiny verification helper.
create or replace function public.cp_v404_marketplace_role_cleanup_check()
returns table (
  email text,
  role text,
  marketplace_role text,
  normalized_marketplace_role text
)
language sql
security definer
set search_path = public
as $$
  select
    p.email,
    p.role,
    p.marketplace_role,
    case
      when lower(coalesce(p.marketplace_role, p.role, '')) in ('admin','dispatch','legacy_dispatch','legacy-dispatch') then 'platform_admin'
      else lower(coalesce(p.marketplace_role, p.role, ''))
    end as normalized_marketplace_role
  from public.profiles p
  order by p.created_at desc nulls last, p.email;
$$;

grant execute on function public.cp_v404_marketplace_role_cleanup_check() to authenticated;

commit;

-- =====================================================================
-- END: RUN_AFTER_V404_MARKETPLACE_ROLE_CLEANUP.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V405_AGENCY_GUARD_DIRECT_ADD.sql
-- =====================================================================
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

-- =====================================================================
-- END: RUN_AFTER_V405_AGENCY_GUARD_DIRECT_ADD.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V406_AGENCY_ASSIGNMENT_UI_FIX.sql
-- =====================================================================
-- Co Pilot Security Marketplace v4.0.6
-- Agency Assignment UI Fix
-- No schema changes are required. This file only refreshes PostgREST schema cache.

notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V406_AGENCY_ASSIGNMENT_UI_FIX.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V407_AGENCY_LIVE_GPS_ROUTE_VISIBILITY.sql
-- =====================================================================
-- Co Pilot Security Marketplace v4.0.7
-- AGENCY LIVE GPS ROUTE VISIBILITY
-- No schema change required for this UI/logic patch.
-- Run this optional cache refresh after uploading v4.0.7.

notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V407_AGENCY_LIVE_GPS_ROUTE_VISIBILITY.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V408_AGENCY_LIVE_GPS_BOOT_FIX.sql
-- =====================================================================
-- v4.0.8 Agency Live GPS Boot Fix
-- No schema change required. This only refreshes PostgREST schema cache.
notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V408_AGENCY_LIVE_GPS_BOOT_FIX.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V409_PLATFORM_COMMAND_CENTER_MAP.sql
-- =====================================================================
-- Co Pilot Security Marketplace v4.0.9 Platform Command Center Map
-- No schema changes are required for this build. This file only refreshes PostgREST schema cache.
notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V409_PLATFORM_COMMAND_CENTER_MAP.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V410_PLATFORM_REAL_MAP_ALIGNMENT.sql
-- =====================================================================
-- v4.0.10 Platform Real Map Alignment
-- No schema change required. Optional PostgREST schema cache refresh only.
notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V410_PLATFORM_REAL_MAP_ALIGNMENT.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V411_GUARD_MARKETPLACE_JOB_FLOW.sql
-- =====================================================================

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

-- =====================================================================
-- END: RUN_AFTER_V411_GUARD_MARKETPLACE_JOB_FLOW.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V412_PLATFORM_LIFECYCLE_SYNC_FIX.sql
-- =====================================================================
-- Co Pilot Security Marketplace v4.0.12
-- PLATFORM LIFECYCLE SYNC FIX
-- This build is primarily front-end lifecycle sync. Run after v4.0.11 only to refresh PostgREST schema cache.
-- Platform Command Center reads marketplace_jobs.current_status + job_events + proof_items.

notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V412_PLATFORM_LIFECYCLE_SYNC_FIX.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V413_BUILD_LABEL_LOCK_FIX.sql
-- =====================================================================
-- Co Pilot Security Marketplace v4.0.13
-- Build Label Lock Fix
-- No schema change required. Optional PostgREST cache refresh only.
notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V413_BUILD_LABEL_LOCK_FIX.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V414_MARKETPLACE_ACTIVITY_GUARD_STATUS_FEED.sql
-- =====================================================================
-- Co Pilot Security Marketplace v4.0.14
-- MARKETPLACE ACTIVITY GUARD STATUS FEED
-- No schema change required. Refresh PostgREST schema cache only.
notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V414_MARKETPLACE_ACTIVITY_GUARD_STATUS_FEED.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V415_BADGE_HARD_LOCK_ACTIVITY_FEED.sql
-- =====================================================================
-- v4.0.15 Badge Hard Lock + Activity Feed
-- No schema changes required. Optional PostgREST schema refresh only.
notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V415_BADGE_HARD_LOCK_ACTIVITY_FEED.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V416_SCRIPT_CACHE_KILLER_ACTIVITY_FEED.sql
-- =====================================================================
notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V416_SCRIPT_CACHE_KILLER_ACTIVITY_FEED.sql
-- =====================================================================

-- =====================================================================
-- BEGIN: RUN_AFTER_V417_SERVER_ROOT_ENTRY_LOCK_ACTIVITY_FEED.sql
-- =====================================================================
-- Co Pilot Security Marketplace v4.0.17
-- SERVER ROOT ENTRY LOCK + ACTIVITY FEED
-- No schema change required. Optional PostgREST cache refresh only.
notify pgrst, 'reload schema';

-- =====================================================================
-- END: RUN_AFTER_V417_SERVER_ROOT_ENTRY_LOCK_ACTIVITY_FEED.sql
-- =====================================================================

notify pgrst, 'reload schema';


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
