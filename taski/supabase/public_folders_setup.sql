-- ============================================================
--  Public (shared) folders — run once in Supabase SQL Editor
-- ============================================================

-- 1. Columns -------------------------------------------------
alter table public.folders add column if not exists is_public boolean not null default false;
alter table public.tasks   add column if not exists creator_name text;

-- 2. Membership + invites -----------------------------------
-- PowerSync requires a single `id` primary key per synced table, so the
-- membership uniqueness is a separate UNIQUE constraint (not the PK).
create table if not exists public.folder_members (
  id        uuid primary key default gen_random_uuid(),
  folder_id uuid not null references public.folders(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz default now(),
  unique (folder_id, user_id)
);
alter table public.folder_members enable row level security;

create table if not exists public.folder_invites (
  id          uuid primary key default gen_random_uuid(),
  folder_id   uuid not null references public.folders(id) on delete cascade,
  sender_id   uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  status      text not null default 'pending',
  created_at  timestamptz default now(),
  unique (folder_id, receiver_id),
  check (status in ('pending','accepted','declined'))
);
alter table public.folder_invites enable row level security;

-- The owner is always a member (single source of truth for access + credit).
create or replace function public.add_owner_membership()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.folder_members(folder_id, user_id)
    values (new.id, new.user_id) on conflict do nothing;
  return new;
end; $$;
drop trigger if exists on_folder_created on public.folders;
create trigger on_folder_created after insert on public.folders
  for each row execute function public.add_owner_membership();

-- Backfill existing folders.
insert into public.folder_members(folder_id, user_id)
  select id, user_id from public.folders on conflict do nothing;

-- 3. Membership helper (security definer → no RLS recursion) -
create or replace function public.is_folder_member(fid uuid)
returns boolean language sql security definer set search_path = '' as $$
  select exists (
    select 1 from public.folder_members
    where folder_id = fid and user_id = auth.uid()
  );
$$;

-- 4. RLS -----------------------------------------------------
-- Folders: members can read; only the owner manages.
drop policy if exists "folders_select" on public.folders;
drop policy if exists "folders_insert" on public.folders;
drop policy if exists "folders_update" on public.folders;
drop policy if exists "folders_delete" on public.folders;
-- Owner can always select their own folder (avoids an RLS race where the
-- after-insert membership trigger hasn't run yet); members see it too.
create policy "folders_select" on public.folders for select
  using (auth.uid() = user_id or public.is_folder_member(id));
create policy "folders_insert" on public.folders for insert with check (auth.uid() = user_id);
create policy "folders_update" on public.folders for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "folders_delete" on public.folders for delete using (auth.uid() = user_id);

-- Tasks: members can read/add/check; only the folder owner deletes.
drop policy if exists "tasks_select" on public.tasks;
drop policy if exists "tasks_insert" on public.tasks;
drop policy if exists "tasks_update" on public.tasks;
drop policy if exists "tasks_delete" on public.tasks;
create policy "tasks_select" on public.tasks for select
  using (auth.uid() = user_id or public.is_folder_member(folder_id));
create policy "tasks_insert" on public.tasks for insert
  with check (auth.uid() = user_id and public.is_folder_member(folder_id));
create policy "tasks_update" on public.tasks for update using (public.is_folder_member(folder_id));
create policy "tasks_delete" on public.tasks for delete
  using (auth.uid() = (select f.user_id from public.folders f where f.id = folder_id));

-- folder_members: members can read; writes happen via trigger / RPC (definer).
drop policy if exists "members_select" on public.folder_members;
create policy "members_select" on public.folder_members for select using (public.is_folder_member(folder_id));

-- folder_invites: sender + receiver can read; receiver updates status.
drop policy if exists "invites_select" on public.folder_invites;
drop policy if exists "invites_update" on public.folder_invites;
create policy "invites_select" on public.folder_invites for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "invites_update" on public.folder_invites for update
  using (auth.uid() = receiver_id) with check (auth.uid() = receiver_id);

-- 5. RPCs ----------------------------------------------------
create or replace function public.my_friends()
returns table(user_id uuid, username text)
language plpgsql security definer set search_path = '' as $$
begin
  return query
  select u.id, u.name
  from public.friend_requests fr
  join public.users u
    on u.id = case when fr.sender_id = auth.uid() then fr.receiver_id else fr.sender_id end
  where fr.status = 'accepted'
    and (fr.sender_id = auth.uid() or fr.receiver_id = auth.uid());
end; $$;

create or replace function public.invite_to_folder(p_folder_id uuid, p_username text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare target uuid; new_id uuid;
begin
  if not exists (select 1 from public.folders where id = p_folder_id and user_id = auth.uid()) then
    raise exception 'not_owner';
  end if;
  select id into target from public.users where lower(name) = lower(p_username) limit 1;
  if target is null then raise exception 'user_not_found'; end if;
  if target = auth.uid() then raise exception 'self_invite'; end if;
  if exists (select 1 from public.folder_members where folder_id = p_folder_id and user_id = target) then
    raise exception 'already_member';
  end if;
  insert into public.folder_invites(folder_id, sender_id, receiver_id)
    values (p_folder_id, auth.uid(), target)
    on conflict (folder_id, receiver_id) do nothing
    returning id into new_id;
  if new_id is null then raise exception 'invite_exists'; end if;
  return new_id;
end; $$;

create or replace function public.pending_folder_invites()
returns table(id uuid, folder_id uuid, folder_name text, sender_username text, created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  return query
  select fi.id, fi.folder_id, f.name, u.name, fi.created_at
  from public.folder_invites fi
  join public.folders f on f.id = fi.folder_id
  join public.users u on u.id = fi.sender_id
  where fi.receiver_id = auth.uid() and fi.status = 'pending'
  order by fi.created_at desc;
end; $$;

create or replace function public.accept_folder_invite(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare fid uuid;
begin
  update public.folder_invites set status = 'accepted'
   where id = p_id and receiver_id = auth.uid() and status = 'pending'
   returning folder_id into fid;
  if fid is not null then
    insert into public.folder_members(folder_id, user_id)
      values (fid, auth.uid()) on conflict do nothing;
  end if;
end; $$;

create or replace function public.decline_folder_invite(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.folder_invites set status = 'declined'
   where id = p_id and receiver_id = auth.uid() and status = 'pending';
end; $$;

-- 6. Shared credit: milestone trigger credits ALL members ----
-- (private folder → just the owner, since owner is the only member)
create or replace function public.bump_completed_count()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (tg_op = 'INSERT' and new.completed)
     or (tg_op = 'UPDATE' and new.completed and not coalesce(old.completed, false)) then
    update public.users set completed_count = completed_count + 1
     where id in (select user_id from public.folder_members where folder_id = new.folder_id);
  end if;
  return new;
end; $$;

-- 7. Shared credit: leaderboard counts by membership ---------
create or replace function public.leaderboard(p_range text)
returns table(user_id uuid, username text, completed_count int)
language plpgsql security definer set search_path = '' as $$
declare since timestamptz;
begin
  since := case p_range
    when 'day'  then now() - interval '1 day'
    when 'week' then now() - interval '7 days'
    else now() - interval '1 day' end;
  return query
  with my_circle as (
    select case when sender_id = auth.uid() then receiver_id else sender_id end as fid
      from public.friend_requests
     where status = 'accepted' and (sender_id = auth.uid() or receiver_id = auth.uid())
    union select auth.uid()
  )
  select u.id, u.name, count(t.id)::int
  from my_circle c
  join public.users u on u.id = c.fid
  left join public.tasks t
    on t.completed and t.completed_at >= since
   and t.folder_id in (select fm.folder_id from public.folder_members fm where fm.user_id = u.id)
  group by u.id, u.name
  order by count(t.id) desc, u.name asc;
end; $$;

grant execute on function public.my_friends()                  to authenticated;
grant execute on function public.invite_to_folder(uuid, text)  to authenticated;
grant execute on function public.pending_folder_invites()      to authenticated;
grant execute on function public.accept_folder_invite(uuid)    to authenticated;
grant execute on function public.decline_folder_invite(uuid)   to authenticated;
