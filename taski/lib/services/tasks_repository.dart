import 'package:taski/models/task.dart';
import 'package:taski/services/powersync/powersync_db.dart';
import 'package:taski/services/supabase_client.dart';

/// All reads/writes go to the local PowerSync SQLite database.
/// PowerSync syncs those changes with Supabase in the background.
class TasksRepository {
  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// Live stream of a folder's tasks. Emits immediately and on every change.
  Stream<List<Task>> watch(String folderId) {
    return db
        .watch(
          'SELECT * FROM tasks WHERE folder_id = ? ORDER BY created_at',
          parameters: [folderId],
        )
        .map(
          (rows) => rows
              .map((r) => Task.fromMap(Map<String, dynamic>.from(r)))
              .toList(),
        );
  }

  Future<void> create({required String folderId, required String title}) async {
    final userId = supabase.auth.currentUser!.id;
    await db.execute(
      'INSERT INTO tasks(id, folder_id, user_id, title, completed, '
      'timer_paused, created_at) VALUES(uuid(), ?, ?, ?, 0, 0, ?)',
      [folderId, userId, title, _nowIso()],
    );
  }

  Future<void> rename(String id, String title) async {
    await db.execute('UPDATE tasks SET title = ? WHERE id = ?', [title, id]);
  }

  Future<void> setCompleted(String id, bool completed) async {
    await db.execute(
      'UPDATE tasks SET completed = ?, completed_at = ? WHERE id = ?',
      [completed ? 1 : 0, completed ? _nowIso() : null, id],
    );
  }

  Future<void> setColor(String id, String? color) async {
    await db.execute('UPDATE tasks SET color = ? WHERE id = ?', [color, id]);
  }

  Future<void> setTimer(String id, DateTime start, DateTime end) async {
    await db.execute(
      'UPDATE tasks SET timer_total_seconds = ?, timer_start = ?, '
      'timer_end = ?, timer_paused = 0, timer_remaining_seconds = NULL '
      'WHERE id = ?',
      [
        end.difference(start).inSeconds,
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
        id,
      ],
    );
  }

  Future<void> pauseTimer(String id, int remainingSeconds) async {
    await db.execute(
      'UPDATE tasks SET timer_paused = 1, timer_remaining_seconds = ?, '
      'timer_end = NULL WHERE id = ?',
      [remainingSeconds, id],
    );
  }

  Future<void> resumeTimer(String id, DateTime start, DateTime end) async {
    await db.execute(
      'UPDATE tasks SET timer_paused = 0, timer_start = ?, timer_end = ?, '
      'timer_remaining_seconds = NULL WHERE id = ?',
      [start.toUtc().toIso8601String(), end.toUtc().toIso8601String(), id],
    );
  }

  Future<void> clearTimer(String id) async {
    await db.execute(
      'UPDATE tasks SET timer_total_seconds = NULL, timer_start = NULL, '
      'timer_end = NULL, timer_paused = 0, timer_remaining_seconds = NULL '
      'WHERE id = ?',
      [id],
    );
  }

  Future<void> delete(String id) async {
    await db.execute('DELETE FROM tasks WHERE id = ?', [id]);
  }
}
