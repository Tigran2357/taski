import 'package:taski/models/task.dart';

class Folder {
  String name;
  final List<Task> tasks;

  Folder({required this.name, List<Task>? tasks}) : tasks = tasks ?? [];

  double get progress => tasks.isEmpty
      ? 0
      : tasks.where((t) => t.completed).length / tasks.length;
}
