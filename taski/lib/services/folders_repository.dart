import 'package:flutter/foundation.dart';
import 'package:taski/models/folder.dart';
import 'package:taski/services/powersync/powersync_db.dart';
import 'package:taski/services/supabase_client.dart';
import 'package:uuid/uuid.dart';

/// All reads/writes go to the local PowerSync SQLite database.
/// PowerSync syncs those changes with Supabase in the background.
class FoldersRepository {
  /// Live stream of folders, each with its tasks embedded.
  /// Re-emits when either `folders` or `tasks` changes (offline-aware).
  Stream<List<Folder>> watchAll() {
    debugPrint('PS: watchAll() called (subscribing)');
    // One-shot probe: can we read the local db at all, and how many folders?
    () async {
      try {
        final r = await db.getAll('SELECT * FROM folders');
        debugPrint('PS: getAll folders = ${r.length}');
      } catch (e) {
        debugPrint('PS: getAll FAILED: $e');
      }
    }();
    return db
        .watch(
          'SELECT * FROM folders ORDER BY created_at',
          // Folders' task progress depends on the tasks table too, so re-run
          // whenever either table changes.
          triggerOnTables: const ['folders', 'tasks'],
        )
        .asyncMap((folderRows) async {
          debugPrint('PS: watchAll emitted ${folderRows.length} folder rows');
          final folders = <Folder>[];
          for (final fr in folderRows) {
            final taskRows = await db.getAll(
              'SELECT * FROM tasks WHERE folder_id = ? ORDER BY created_at',
              [fr['id']],
            );
            folders.add(
              Folder.fromMap({
                ...Map<String, dynamic>.from(fr),
                'tasks': taskRows
                    .map((r) => Map<String, dynamic>.from(r))
                    .toList(),
              }),
            );
          }
          return folders;
        });
  }

  /// Creates a folder and returns its id (needed to invite friends to a
  /// public folder). The owner membership row is added server-side by a
  /// trigger. The id is generated client-side so we can use it immediately.
  Future<String> create(String name, {bool isPublic = false}) async {
    final userId = supabase.auth.currentUser!.id;
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.execute(
      'INSERT INTO folders(id, user_id, name, created_at, is_public) '
      'VALUES(?, ?, ?, ?, ?)',
      [id, userId, name, now, isPublic ? 1 : 0],
    );
    return id;
  }

  Future<void> rename(String id, String name) async {
    await db.execute('UPDATE folders SET name = ? WHERE id = ?', [name, id]);
  }

  Future<void> setColor(String id, String? color) async {
    await db.execute('UPDATE folders SET color = ? WHERE id = ?', [color, id]);
  }

  /// Deletes a folder and its tasks. Local SQLite has no FK cascade, so we
  /// remove the tasks explicitly in the same transaction.
  Future<void> delete(String id) async {
    await db.writeTransaction((tx) async {
      await tx.execute('DELETE FROM tasks WHERE folder_id = ?', [id]);
      await tx.execute('DELETE FROM folders WHERE id = ?', [id]);
    });
  }
}
