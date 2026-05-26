import 'package:taski/models/task.dart';
import 'package:taski/services/supabase_client.dart';

class TasksRepository {
  Future<Task> create({required String folderId, required String title}) async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase
        .from('tasks')
        .insert({'folder_id': folderId, 'title': title, 'user_id': userId})
        .select(
          'id, folder_id, title, completed, color, timer_total_seconds, '
          'timer_start, timer_end, timer_paused, timer_remaining_seconds',
        )
        .single();
    return Task.fromMap(row);
  }

  Future<void> rename(String id, String title) async {
    await supabase.from('tasks').update({'title': title}).eq('id', id);
  }

  Future<void> setCompleted(String id, bool completed) async {
    await supabase.from('tasks').update({'completed': completed}).eq('id', id);
  }

  Future<void> setColor(String id, String? color) async {
    await supabase.from('tasks').update({'color': color}).eq('id', id);
  }

  Future<void> setTimer(String id, DateTime start, DateTime end) async {
    await supabase
        .from('tasks')
        .update({
          'timer_total_seconds': end.difference(start).inSeconds,
          'timer_start': start.toUtc().toIso8601String(),
          'timer_end': end.toUtc().toIso8601String(),
          'timer_paused': false,
          'timer_remaining_seconds': null,
        })
        .eq('id', id);
  }

  Future<void> pauseTimer(String id, int remainingSeconds) async {
    await supabase
        .from('tasks')
        .update({
          'timer_paused': true,
          'timer_remaining_seconds': remainingSeconds,
          'timer_end': null,
        })
        .eq('id', id);
  }

  Future<void> resumeTimer(String id, DateTime start, DateTime end) async {
    await supabase
        .from('tasks')
        .update({
          'timer_paused': false,
          'timer_start': start.toUtc().toIso8601String(),
          'timer_end': end.toUtc().toIso8601String(),
          'timer_remaining_seconds': null,
        })
        .eq('id', id);
  }

  Future<void> clearTimer(String id) async {
    await supabase
        .from('tasks')
        .update({
          'timer_total_seconds': null,
          'timer_start': null,
          'timer_end': null,
          'timer_paused': false,
          'timer_remaining_seconds': null,
        })
        .eq('id', id);
  }


  Future<void> delete(String id) async {
    await supabase.from('tasks').delete().eq('id', id);
  }
}
