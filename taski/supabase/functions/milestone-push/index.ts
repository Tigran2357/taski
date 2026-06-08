// Supabase Edge Function: milestone-push
//
// Triggered by a Database Webhook on `users` UPDATE. A completion bumps the
// user's all-time `completed_count` (a "ping"), which fires this function. We
// then look at the user's count of tasks completed THIS WEEK (shared credit,
// membership-based) and, if it just hit a milestone, push to their friends —
// at most once per milestone per week.
//
// Secret required: FIREBASE_SERVICE_ACCOUNT (same as before).

import admin from 'npm:firebase-admin@12';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const serviceAccount = JSON.parse(
  Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}',
);
if (admin.apps.length === 0) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

// 15,30,…,105 then 150,200,… (weekly counts stay small in practice)
function isMilestone(n: number): boolean {
  if (n <= 0) return false;
  return n <= 105 ? n % 15 === 0 : n % 50 === 0;
}

Deno.serve(async (req) => {
  const payload = await req.json();
  const record = payload.record;
  const oldRecord = payload.old_record;
  if (!record) return new Response('no record', { status: 200 });

  // Only react to a completion ping (completed_count increased).
  if ((record.completed_count ?? 0) <= (oldRecord?.completed_count ?? 0)) {
    return new Response('no increase', { status: 200 });
  }

  const userId: string = record.id;
  const username: string = record.name ?? 'Your friend';

  // Tasks completed THIS WEEK (resets every week).
  const { data: weekly } = await supabase.rpc('weekly_completed_count', {
    p_user_id: userId,
  });
  const count = (weekly ?? 0) as number;
  if (!isMilestone(count)) return new Response('not a milestone', { status: 200 });

  // Fire at most once per (user, week, milestone).
  const { data: isNew } = await supabase.rpc('claim_weekly_milestone', {
    p_user_id: userId,
    p_milestone: count,
  });
  if (!isNew) return new Response('already sent', { status: 200 });

  // Friends (accepted, either direction).
  const { data: friendRows } = await supabase
    .from('friend_requests')
    .select('sender_id, receiver_id')
    .eq('status', 'accepted')
    .or(`sender_id.eq.${userId},receiver_id.eq.${userId}`);
  const friendIds = (friendRows ?? []).map((r: any) =>
    r.sender_id === userId ? r.receiver_id : r.sender_id
  );
  if (friendIds.length === 0) return new Response('no friends', { status: 200 });

  const { data: tokenRows } = await supabase
    .from('device_tokens')
    .select('token')
    .in('user_id', friendIds);
  const tokens = (tokenRows ?? []).map((r: any) => r.token);
  if (tokens.length === 0) return new Response('no tokens', { status: 200 });

  const templates = [
    `${username} is killing it with ${count} tasks this week!!!, can you beat em?`,
    `your friend ${username} already did ${count} tasks this week, what about you?`,
  ];
  const body = templates[Math.floor(Math.random() * templates.length)];

  const messaging = admin.messaging();
  await Promise.all(
    tokens.map((token: string) =>
      messaging
        .send({
          token,
          notification: { title: 'Taski', body },
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default' } } },
        })
        .catch((e: any) => console.error('FCM send failed', e))
    ),
  );

  return new Response('ok', { status: 200 });
});
