import 'package:shared_preferences/shared_preferences.dart';
import 'package:taski/services/supabase_client.dart';

/// Outcome of a sign-up attempt.
enum SignUpResult {
  /// A session was created immediately (email confirmation is off).
  signedIn,

  /// Account created; a confirmation email was sent.
  confirmationSent,

  /// An account with this email already exists.
  emailAlreadyExists,
}

class AuthService {
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final res = await supabase.auth.signUp(email: email, password: password);
    if (res.session != null) {
      return SignUpResult.signedIn;
    }
    // Supabase returns a user with an empty `identities` list when the email
    // is already registered (anti-enumeration), instead of throwing.
    final identities = res.user?.identities;
    if (identities != null && identities.isEmpty) {
      return SignUpResult.emailAlreadyExists;
    }
    return SignUpResult.confirmationSent;
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => supabase.auth.signOut();

  String _nameKey(String uid) => 'profile_name_$uid';

  /// Returns the saved name for the logged-in user, or null if not set.
  ///
  /// Reads a local cache first so it works offline and never throws — the
  /// `users` table isn't synced by PowerSync, so a direct query would fail with
  /// no network and hang the auth gate. Only hits Supabase if uncached.
  Future<String?> currentName() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_nameKey(user.id));
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final row = await supabase
          .from('users')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      final name = row?['name'] as String?;
      if (name != null && name.isNotEmpty) {
        await prefs.setString(_nameKey(user.id), name);
      }
      return name;
    } catch (_) {
      return null; // offline and not cached yet
    }
  }

  /// Saves the profile row for the logged-in user. Caches locally first, then
  /// writes to Supabase. Runs after login, so RLS passes.
  Future<void> saveName(String name) async {
    final user = supabase.auth.currentUser!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey(user.id), name);
    await supabase.from('users').upsert({
      'id': user.id,
      'email': user.email,
      'name': name,
    });
  }
}
