-- ============================================================
--  Public-folder join / leave activity — run in SQL Editor
-- ============================================================

-- 1. Events table (one row per join / leave). Has an `id` PK for PowerSync.
create table if not exists public.folder_events (
  id         uuid primary key default gen_random_uuid(),
  folder_id  uuid not null references public.folders(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  username   text not null,
  type       text not null check (type in ('joined','left')),
  created_at timestamptz default now()
);
alter table public.folder_events enable row level security;

-- Any member of the folder can read its events. Writes happen only via the
-- security-definer RPCs below.
drop policy if exists "events_select" on public.folder_events;
create policy "events_select" on public.folder_events for select
  using (public.is_folder_member(folder_id));

-- 2. Accepting an invite now also logs a "joined" event.
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
    insert into public.folder_events(folder_id, user_id, username, type)
      values (fid, auth.uid(),
              (select name from public.users where id = auth.uid()), 'joined');
  end if;
end; $$;

-- 3. Leaving a folder: log a "left" event, then drop the membership.
--    (The owner can't leave — they delete the folder instead.)
create or replace function public.leave_folder(p_folder_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.folders where id = p_folder_id and user_id = auth.uid()) then
    raise exception 'owner_cannot_leave';
  end if;
  insert into public.folder_events(folder_id, user_id, username, type)
    values (p_folder_id, auth.uid(),
            (select name from public.users where id = auth.uid()), 'left');
  delete from public.folder_members
   where folder_id = p_folder_id and user_id = auth.uid();
end; $$;

grant execute on function public.leave_folder(uuid) to authenticated;

-- 4. Add the table to the PowerSync publication so it replicates.
alter publication powersync add table public.folder_events;
