// Supabase Edge Function: new-task-push
//
// Triggered by a Database Webhook on `tasks` INSERT. If the task's folder is
// public, pushes an FCM notification to every member except the creator.
// No-ops for private folders.
//
// Secret required: FIREBASE_SERVICE_ACCOUNT (same as milestone-push).

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

Deno.serve(async (req) => {
  const payload = await req.json();
  const task = payload.record;
  if (!task) return new Response('no record', { status: 200 });

  // Only notify for public folders.
  const { data: folder } = await supabase
    .from('folders').select('name, is_public').eq('id', task.folder_id).single();
  if (!folder?.is_public) return new Response('private folder', { status: 200 });

  // Members except the creator.
  const { data: memberRows } = await supabase
    .from('folder_members').select('user_id').eq('folder_id', task.folder_id);
  const memberIds = (memberRows ?? [])
    .map((r: any) => r.user_id)
    .filter((id: string) => id !== task.user_id);
  if (memberIds.length === 0) return new Response('no other members', { status: 200 });

  const { data: tokenRows } = await supabase
    .from('device_tokens').select('token').in('user_id', memberIds);
  const tokens = (tokenRows ?? []).map((r: any) => r.token);
  if (tokens.length === 0) return new Response('no tokens', { status: 200 });

  const creator = task.creator_name ?? 'Someone';
  const body = `${creator} added a task to "${folder.name}"`;
  const messaging = admin.messaging();
  await Promise.all(tokens.map((token: string) =>
    messaging.send({
      token,
      notification: { title: folder.name, body },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    }).catch((e: any) => console.error('FCM send failed', e)),
  ));

  return new Response('ok', { status: 200 });
});
