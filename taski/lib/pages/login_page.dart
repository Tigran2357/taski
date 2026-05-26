import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taski/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validate(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      return 'Please fill in all fields.';
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return "That email address doesn't look right.";
    }
    if (_isSignUp && password.length < 6) {
      return 'Password is too short — use at least 6 characters.';
    }
    return null;
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Incorrect email or password. If you don\'t have an '
              'account yet, tap "Sign up".';
        case 'user_already_exists':
        case 'email_exists':
          return 'An account with this email already exists. Try signing in '
              'instead.';
        case 'weak_password':
          return 'Password is too short — use at least 6 characters.';
        case 'email_address_invalid':
        case 'validation_failed':
          return "That email address doesn't look right.";
        case 'email_not_confirmed':
          return 'Please confirm your email first — check your inbox for a '
              'verification link.';
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          return 'Too many attempts. Please wait a moment and try again.';
      }
      return error.message;
    }
    return 'Something went wrong. Please check your connection and try again.';
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final validationError = _validate(email, password);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_isSignUp) {
        final result = await _auth.signUp(email: email, password: password);
        if (!mounted) return;
        switch (result) {
          case SignUpResult.signedIn:
            // The gate will navigate away on its own.
            break;
          case SignUpResult.confirmationSent:
            setState(() {
              _isSignUp = false;
              _info = 'Account created! Please confirm your email, '
                  'then sign in below.';
            });
          case SignUpResult.emailAlreadyExists:
            setState(() {
              _isSignUp = false;
              _error = 'An account with this email already exists. '
                  'Try signing in instead.';
            });
        }
      } else {
        await _auth.signIn(email: email, password: password);
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isSignUp ? 'Create account' : 'Sign in',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_info != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _info!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isSignUp ? 'Sign up' : 'Sign in'),
              ),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                      _info = null;
                    }),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Sign in'
                    : "Don't have an account? Sign up",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
