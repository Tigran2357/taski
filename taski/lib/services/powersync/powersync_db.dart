import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taski/services/powersync/schema.dart';
import 'package:taski/services/powersync/supabase_connector.dart';

/// Global handle to the on-device PowerSync database.
/// Reads/writes go here; PowerSync syncs it with Supabase in the background.
late final PowerSyncDatabase db;

bool _opened = false;

Future<String> _dbPath() async {
  const name = 'taski.db';
  if (kIsWeb) return name;
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, name);
}

/// Opens the local database and wires sync to the user's auth state.
/// The local open is fast (no network); sync runs in the background.
Future<void> openPowerSync() async {
  if (_opened) return;
  db = PowerSyncDatabase(schema: schema, path: await _dbPath());
  await db.initialize();
  _opened = true;

  final auth = Supabase.instance.client.auth;
  SupabaseConnector? connector;

  // Connect now if already logged in.
  if (auth.currentSession != null) {
    connector = SupabaseConnector(db);
    db.connect(connector: connector);
  }

  // Connect on login, clear on logout, refresh creds on token refresh.
  auth.onAuthStateChange.listen((data) async {
    switch (data.event) {
      case AuthChangeEvent.signedIn:
        connector = SupabaseConnector(db);
        db.connect(connector: connector!);
      case AuthChangeEvent.signedOut:
        connector = null;
        // Clear local data so the next user on this device starts clean.
        await db.disconnectAndClear();
      case AuthChangeEvent.tokenRefreshed:
        connector?.prefetchCredentials();
      default:
        break;
    }
  });
}
