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

  /// Returns the saved name for the logged-in user, or null if they haven't
  /// set one yet.
  Future<String?> currentName() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final row = await supabase
        .from('users')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();
    return row?['name'] as String?;
  }

  /// Saves the profile row for the logged-in user. Runs after login, so a
  /// session exists and the row passes the RLS check.
  Future<void> saveName(String name) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('users').upsert({
      'id': user.id,
      'email': user.email,
      'name': name,
    });
  }
}
