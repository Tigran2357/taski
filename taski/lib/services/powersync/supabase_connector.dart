import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Postgres response codes we can't recover from by retrying — discard instead.
final List<RegExp> _fatalResponseCodes = [
  RegExp(r'^22...$'), // data exception (type mismatch, etc.)
  RegExp(r'^23...$'), // integrity constraint (not null, fk, unique)
  RegExp(r'^42501$'), // insufficient privilege (RLS violation)
];

/// Bridges PowerSync to the existing Supabase backend:
///  - [fetchCredentials] hands PowerSync the instance URL + the user's JWT.
///  - [uploadData] replays the local mutation queue against Supabase.
class SupabaseConnector extends PowerSyncBackendConnector {
  final PowerSyncDatabase db;
  Future<void>? _refreshFuture;

  SupabaseConnector(this.db);

  String get _powersyncUrl => dotenv.env['POWERSYNC_URL']!;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    await _refreshFuture; // wait for any in-flight session refresh

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null; // not logged in → no sync

    return PowerSyncCredentials(
      endpoint: _powersyncUrl,
      token: session.accessToken,
      userId: session.user.id,
      expiresAt: session.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
    );
  }

  @override
  void invalidateCredentials() {
    // PowerSync hit an auth failure — nudge Supabase to refresh the session.
    _refreshFuture = Supabase.instance.client.auth
        .refreshSession()
        .timeout(const Duration(seconds: 5))
        .then((_) => null, onError: (_) => null);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    final rest = Supabase.instance.client.rest;
    CrudEntry? lastOp;
    try {
      for (final op in transaction.crud) {
        lastOp = op;
        final table = rest.from(op.table);
        switch (op.op) {
          case UpdateType.put:
            final data = Map<String, dynamic>.of(op.opData!)..['id'] = op.id;
            await table.upsert(data);
          case UpdateType.patch:
            await table.update(op.opData!).eq('id', op.id);
          case UpdateType.delete:
            await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } on PostgrestException catch (e) {
      if (e.code != null &&
          _fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
        // Fatal (bad data / RLS) — discard so the queue isn't blocked forever.
        debugPrint('PowerSync upload discarded (fatal): $lastOp — $e');
        await transaction.complete();
      } else {
        rethrow; // retryable (network/server) — PowerSync retries later
      }
    }
  }
}
