import 'package:flutter/material.dart';
import 'package:taski/models/folder.dart';
import 'package:taski/models/task.dart';

class FolderPage extends StatefulWidget {
  final Folder folder;
  const FolderPage({super.key, required this.folder});

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  Future<String?> _prompt(String title, {String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTask() async {
    final title = await _prompt('New task');
    if (title == null) return;
    setState(() => widget.folder.tasks.add(Task(title: title)));
  }

  Future<void> _renameTask(Task task) async {
    final title = await _prompt('Rename task', initial: task.title);
    if (title == null) return;
    setState(() => task.title = title);
  }

  void _deleteTask(Task task) {
    setState(() => widget.folder.tasks.remove(task));
  }

  void _toggleTask(Task task) {
    setState(() => task.completed = !task.completed);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.folder.tasks;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.folder.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('No tasks yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              itemBuilder: (_, i) {
                final t = tasks[i];
                return Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: t.completed,
                      onChanged: (_) => _toggleTask(t),
                    ),
                    title: Text(
                      t.title,
                      style: TextStyle(
                        decoration: t.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: t.completed ? Colors.grey : null,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') _renameTask(t);
                        if (v == 'delete') _deleteTask(t);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}
