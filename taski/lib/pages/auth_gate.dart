import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taski/pages/home.dart';
import 'package:taski/pages/login_page.dart';
import 'package:taski/pages/name_page.dart';
import 'package:taski/services/auth_service.dart';
import 'package:taski/services/supabase_client.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  late final StreamSubscription<AuthState> _sub;
  bool _loading = true;
  bool _hasName = false;

  @override
  void initState() {
    super.initState();
    _resolve();
    _sub = supabase.auth.onAuthStateChange.listen((_) => _resolve());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  /// Works out which screen to show: checks for a session, then whether the
  /// user has saved a name.
  Future<void> _resolve() async {
    if (supabase.auth.currentSession == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasName = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    final name = await _auth.currentName();
    if (mounted) {
      setState(() {
        _hasName = name != null && name.isNotEmpty;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (supabase.auth.currentSession == null) {
      return const LoginPage();
    }
    if (!_hasName) {
      return NamePage(onSaved: _resolve);
    }
    return const HomePage();
  }
}
