-- ============================================================
--  Weekly summary leaderboard — run once in SQL Editor.
--  Adds a 'last_week' range to the existing leaderboard RPC
--  (the completed week before the current one).
-- ============================================================

create or replace function public.leaderboard(p_range text)
returns table(user_id uuid, username text, completed_count int)
language plpgsql security definer set search_path = '' as $$
declare since timestamptz; until timestamptz;
begin
  if p_range = 'last_week' then
    since := date_trunc('week', now()) - interval '7 days';
    until := date_trunc('week', now());
  else
    since := case p_range
      when 'day'  then now() - interval '1 day'
      when 'week' then now() - interval '7 days'
      else now() - interval '1 day' end;
    until := now() + interval '1 day'; -- effectively no upper bound
  end if;

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
    on t.completed and t.completed_at >= since and t.completed_at < until
   and t.folder_id in (select fm.folder_id from public.folder_members fm where fm.user_id = u.id)
  group by u.id, u.name
  order by count(t.id) desc, u.name asc;
end; $$;
