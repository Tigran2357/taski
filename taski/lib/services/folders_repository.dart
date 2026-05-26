import 'package:taski/models/folder.dart';
import 'package:taski/services/supabase_client.dart';

class FoldersRepository {
  Future<List<Folder>> fetchAll() async {
    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('folders')
        .select(
          'id, name, color, '
          'tasks(id, folder_id, title, completed, color, timer_total_seconds, '
          'timer_start, timer_end, timer_paused, timer_remaining_seconds)',
        )
        .eq('user_id', userId)
        .order('created_at');
    return (rows as List)
        .map((r) => Folder.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Folder> create(String name) async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase
        .from('folders')
        .insert({'name': name, 'user_id': userId})
        .select('id, name, color')
        .single();
    return Folder.fromMap(row);
  }

  Future<void> rename(String id, String name) async {
    await supabase.from('folders').update({'name': name}).eq('id', id);
  }

  Future<void> setColor(String id, String? color) async {
    await supabase.from('folders').update({'color': color}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await supabase.from('folders').delete().eq('id', id);
  }
}
