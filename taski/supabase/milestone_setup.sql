-- ============================================================
--  Milestone push setup — run once in Supabase SQL Editor
-- ============================================================

-- 1. Cumulative completed-task counter on users (never decreases).
alter table public.users
  add column if not exists completed_count int not null default 0;

-- 2. Trigger: bump the counter the moment a task becomes completed.
--    Fires server-side when PowerSync syncs the completion up, so it works
--    even when the completion happened offline. Never decrements.
create or replace function public.bump_completed_count()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  if (tg_op = 'INSERT' and new.completed) then
    update public.users
       set completed_count = completed_count + 1
     where id = new.user_id;
  elsif (tg_op = 'UPDATE'
         and new.completed
         and not coalesce(old.completed, false)) then
    update public.users
       set completed_count = completed_count + 1
     where id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_task_completed on public.tasks;
create trigger on_task_completed
  after insert or update of completed on public.tasks
  for each row execute function public.bump_completed_count();

-- 3. FCM device tokens (one row per device, keyed by token).
create table if not exists public.device_tokens (
  token      text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  platform   text,
  updated_at timestamptz default now()
);
alter table public.device_tokens enable row level security;

drop policy if exists "own tokens" on public.device_tokens;
create policy "own tokens" on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 4. After running this, create a Database Webhook (Dashboard → Database →
--    Webhooks) on table `users`, event UPDATE, pointing at the deployed
--    `milestone-push` Edge Function.
