import 'package:taski/models/task.dart';

class Folder {
  final String id;
  String name;
  final List<Task> tasks;

  /// Hex color for the folder banner, e.g. '#90CAF9'. Null = default card color.
  String? color;

  Folder({required this.id, required this.name, List<Task>? tasks, this.color})
    : tasks = tasks ?? [];

  double get progress => tasks.isEmpty
      ? 0
      : tasks.where((t) => t.completed).length / tasks.length;

  /// The task whose timer is running/paused with the least time left, if any.
  /// The folder banner mirrors this task's countdown.
  Task? get activeTimerTask {
    final now = DateTime.now();
    Task? best;
    for (final t in tasks) {
      if (t.isTimerVisible(now)) {
        if (best == null || t.remaining(now) < best.remaining(now)) best = t;
      }
    }
    return best;
  }

  factory Folder.fromMap(Map<String, dynamic> map) => Folder(
    id: map['id'] as String,
    name: map['name'] as String,
    color: map['color'] as String?,
    tasks: (map['tasks'] as List? ?? [])
        .map((t) => Task.fromMap(t as Map<String, dynamic>))
        .toList(),
  );
}
