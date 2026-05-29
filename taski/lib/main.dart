import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taski/pages/auth_gate.dart';
import 'package:taski/services/notification_service.dart';
import 'package:taski/services/supabase_client.dart';

/// Globally-readable theme mode. Toggled by double-tapping the app title.
/// Persisted via shared_preferences so the choice survives restarts.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);

const _themePrefKey = 'themeMode';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore the saved theme before the first frame so there's no flash.
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_themePrefKey) == 'dark') {
    appThemeMode.value = ThemeMode.dark;
  }
  // Persist any future change.
  appThemeMode.addListener(() {
    prefs.setString(
      _themePrefKey,
      appThemeMode.value == ThemeMode.dark ? 'dark' : 'light',
    );
  });

  await initSupabase();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  runApp(const MyApp());
}

// Built once — never recreated on theme toggle so no full tree rebuild.
final _lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  textTheme: GoogleFonts.nunitoTextTheme(),
);
final _darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0F1726),
  textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (_, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        // Smooth cross-fade between light and dark instead of an instant swap.
        themeAnimationDuration: const Duration(milliseconds: 200),
        themeAnimationCurve: Curves.easeInOut,
        home: const AuthGate(),
      ),
    );
  }
}
