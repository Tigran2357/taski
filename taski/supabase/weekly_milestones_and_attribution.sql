-- ============================================================
--  Completion attribution + weekly-resetting milestones
--  Run once in Supabase SQL Editor.
-- ============================================================

-- 1. Who completed a task (denormalised, like creator_name).
alter table public.tasks add column if not exists completed_by_name text;

-- 2. Per-week dedup so a milestone fires at most once per user per week.
create table if not exists public.milestone_sent (
  user_id    uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  milestone  int  not null,
  sent_at    timestamptz default now(),
  primary key (user_id, week_start, milestone)
);
alter table public.milestone_sent enable row level security;

-- 3. Tasks the user got credit for THIS WEEK (membership-based → shared credit).
create or replace function public.weekly_completed_count(p_user_id uuid)
returns int language sql security definer set search_path = '' as $$
  select count(*)::int from public.tasks t
  where t.completed
    and t.completed_at >= date_trunc('week', now())
    and t.folder_id in (
      select folder_id from public.folder_members where user_id = p_user_id
    );
$$;

-- 4. Claim a milestone for the current week. Returns true only the first time.
create or replace function public.claim_weekly_milestone(p_user_id uuid, p_milestone int)
returns boolean language plpgsql security definer set search_path = '' as $$
declare cnt int;
begin
  insert into public.milestone_sent(user_id, week_start, milestone)
    values (p_user_id, date_trunc('week', now())::date, p_milestone)
    on conflict do nothing;
  get diagnostics cnt = row_count;
  return cnt > 0;
end; $$;

-- Only the Edge Function (service role) should call these.
revoke all on function public.weekly_completed_count(uuid)        from public;
revoke all on function public.claim_weekly_milestone(uuid, int)   from public;
grant execute on function public.weekly_completed_count(uuid)      to service_role;
grant execute on function public.claim_weekly_milestone(uuid, int) to service_role;
