import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taski/pages/auth_gate.dart';
import 'package:taski/services/notification_service.dart';
import 'package:taski/services/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
      home: const AuthGate(),
    );
  }
}

