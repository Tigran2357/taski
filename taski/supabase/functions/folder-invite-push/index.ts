// Supabase Edge Function: folder-invite-push
//
// Triggered by a Database Webhook on `folder_invites` INSERT. Pushes an FCM
// notification to the invited user ("X invited you to <folder>").
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
  const inv = payload.record;
  if (!inv) return new Response('no record', { status: 200 });

  // Folder name + inviter name for the message.
  const { data: folder } = await supabase
    .from('folders').select('name').eq('id', inv.folder_id).single();
  const { data: sender } = await supabase
    .from('users').select('name').eq('id', inv.sender_id).single();

  const folderName = folder?.name ?? 'a folder';
  const senderName = sender?.name ?? 'Someone';

  const { data: tokenRows } = await supabase
    .from('device_tokens').select('token').eq('user_id', inv.receiver_id);
  const tokens = (tokenRows ?? []).map((r: any) => r.token);
  if (tokens.length === 0) return new Response('no tokens', { status: 200 });

  const body = `${senderName} invited you to "${folderName}"`;
  const messaging = admin.messaging();
  await Promise.all(tokens.map((token: string) =>
    messaging.send({
      token,
      notification: { title: 'Folder invite', body },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    }).catch((e: any) => console.error('FCM send failed', e)),
  ));

  return new Response('ok', { status: 200 });
});
