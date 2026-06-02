import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taski/firebase_options.dart';
import 'package:taski/services/notification_service.dart';
import 'package:taski/services/supabase_client.dart';

/// Firebase Cloud Messaging integration for milestone push notifications.
///
/// Registers this device's FCM token against the logged-in user so the
/// `milestone-push` Edge Function can target friends' devices. Foreground
/// messages are surfaced via the local [NotificationService]; when the app is
/// backgrounded or closed, Android/iOS display the FCM payload automatically.
///
/// Fully guarded: if Firebase isn't configured yet (no google-services.json /
/// flutterfire configure), [init] throws and the caller ignores it — the app
/// keeps working without push.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _started = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    await _registerToken();
    messaging.onTokenRefresh.listen((_) => _registerToken());

    // Keep the token row in sync with auth state.
    supabase.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
          _registerToken();
        case AuthChangeEvent.signedOut:
          _removeToken();
        default:
          break;
      }
    });

    // App-in-foreground: show the push as a local notification.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        NotificationService.instance.showFriendMilestone(
          n.title ?? 'Taski',
          n.body ?? '',
        );
      }
    });
  }

  Future<void> _registerToken() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await supabase.from('device_tokens').upsert({
      'token': token,
      'user_id': user.id,
      'platform': defaultTargetPlatform.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _removeToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await supabase.from('device_tokens').delete().eq('token', token);
      }
    } catch (_) {
      // Best-effort; ignore if offline or already gone.
    }
  }
}
