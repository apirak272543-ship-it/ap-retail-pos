-- Additive Login background media control plane.
-- Static images are compressed client-side; animated GIFs are validated and preserved.
create table if not exists public.login_background_media (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  target_app text not null check (target_app in ('customer','admin','merchant','rider','retail_pos','all')),
  media_kind text not null check (media_kind in ('static_image','animated_gif')),
  storage_path text not null,
  public_url text not null,
  festival_key text,
  starts_at timestamptz,
  ends_at timestamptz,
  priority integer not null default 0,
  overlay_opacity numeric(3,2) not null default 0.18 check (overlay_opacity >= 0 and overlay_opacity <= 0.85),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  disabled_at timestamptz,
  constraint login_background_media_time_order check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index if not exists login_background_media_target_active_idx
  on public.login_background_media (target_app, is_active, priority desc, starts_at, ends_at);

alter table public.login_background_media enable row level security;

-- Public/authenticated clients may only read active, currently effective media.
drop policy if exists login_background_media_read_effective on public.login_background_media;
create policy login_background_media_read_effective
  on public.login_background_media for select to authenticated
  using (
    is_active = true
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
  );

-- Admin-only writes are exposed through RPC; direct table writes remain blocked.
drop policy if exists login_background_media_admin_write on public.login_background_media;

create or replace function public.login_media_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_profiles p
    where p.user_id = auth.uid()
      and lower(coalesce(p.role, '')) in ('admin','super_admin')
  );
$$;

revoke all on function public.login_media_is_admin() from public, anon;
grant execute on function public.login_media_is_admin() to authenticated;

create or replace function public.admin_list_login_background_media()
returns setof public.login_background_media
language sql
stable
security definer
set search_path = public
as $$
  select * from public.login_background_media
  where public.login_media_is_admin()
  order by is_active desc, priority desc, updated_at desc;
$$;

create or replace function public.admin_upsert_login_background_media(
  p_id uuid default null,
  p_title text default null,
  p_target_app text default null,
  p_media_kind text default null,
  p_storage_path text default null,
  p_public_url text default null,
  p_festival_key text default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_priority integer default 0,
  p_overlay_opacity numeric default 0.18,
  p_is_active boolean default true
)
returns public.login_background_media
language plpgsql
security definer
set search_path = public
as $$
declare v_row public.login_background_media;
begin
  if not public.login_media_is_admin() then
    raise exception 'admin role required';
  end if;
  if nullif(trim(coalesce(p_title, '')), '') is null then raise exception 'title required'; end if;
  if p_target_app not in ('customer','admin','merchant','rider','retail_pos','all') then raise exception 'invalid target_app'; end if;
  if p_media_kind not in ('static_image','animated_gif') then raise exception 'invalid media_kind'; end if;
  if nullif(trim(coalesce(p_storage_path, '')), '') is null or nullif(trim(coalesce(p_public_url, '')), '') is null then raise exception 'media path and URL required'; end if;
  if p_id is null then
    insert into public.login_background_media(title,target_app,media_kind,storage_path,public_url,festival_key,starts_at,ends_at,priority,overlay_opacity,is_active,created_by)
    values (trim(p_title),p_target_app,p_media_kind,trim(p_storage_path),trim(p_public_url),nullif(trim(p_festival_key),''),p_starts_at,p_ends_at,coalesce(p_priority,0),coalesce(p_overlay_opacity,0.18),coalesce(p_is_active,true),auth.uid())
    returning * into v_row;
  else
    update public.login_background_media set title=trim(p_title), target_app=p_target_app, media_kind=p_media_kind, storage_path=trim(p_storage_path), public_url=trim(p_public_url), festival_key=nullif(trim(p_festival_key),''), starts_at=p_starts_at, ends_at=p_ends_at, priority=coalesce(p_priority,0), overlay_opacity=coalesce(p_overlay_opacity,0.18), is_active=coalesce(p_is_active,true), disabled_at=case when coalesce(p_is_active,true) then null else coalesce(disabled_at, now()) end, updated_at=now() where id=p_id returning * into v_row;
    if v_row.id is null then raise exception 'media not found'; end if;
  end if;
  return v_row;
end;
$$;

create or replace function public.admin_disable_login_background_media(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.login_media_is_admin() then raise exception 'admin role required'; end if;
  update public.login_background_media set is_active=false, disabled_at=now(), updated_at=now() where id=p_id;
  return found;
end;
$$;

revoke all on function public.admin_list_login_background_media() from public, anon;
revoke all on function public.admin_upsert_login_background_media(uuid,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,boolean) from public, anon;
revoke all on function public.admin_disable_login_background_media(uuid) from public, anon;
grant execute on function public.admin_list_login_background_media() to authenticated;
grant execute on function public.admin_upsert_login_background_media(uuid,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,boolean) to authenticated;
grant execute on function public.admin_disable_login_background_media(uuid) to authenticated;

-- Client resolver: returns only effective rows and lets each app choose its own target.
create or replace function public.login_resolve_background_media(p_target_app text)
returns setof public.login_background_media
language sql
stable
security definer
set search_path = public
as $$
  select * from public.login_background_media
  where is_active = true
    and target_app in (p_target_app, 'all')
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
  order by (case when target_app = p_target_app then 1 else 0 end) desc,
           (case when festival_key is not null then 1 else 0 end) desc,
           priority desc, updated_at desc;
$$;
revoke all on function public.login_resolve_background_media(text) from public, anon;
grant execute on function public.login_resolve_background_media(text) to authenticated;
