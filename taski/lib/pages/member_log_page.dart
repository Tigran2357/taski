import 'package:flutter/material.dart';
import 'package:taski/models/folder_event.dart';
import 'package:taski/services/tasks_repository.dart';

/// Shows a public folder's join / leave activity, newest first.
class MemberLogPage extends StatelessWidget {
  final String folderId;
  final String folderName;
  const MemberLogPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  String _fmt(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Member log · $folderName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<List<FolderEvent>>(
        stream: TasksRepository().watchEvents(folderId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Newest first.
          final events = snapshot.data!.reversed.toList();
          if (events.isEmpty) {
            return const Center(child: Text('No activity yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (_, i) {
              final e = events[i];
              final left = e.type == 'left';
              return ListTile(
                leading: Icon(
                  left ? Icons.logout : Icons.login,
                  color: left ? Colors.red : Colors.green,
                ),
                title: Text(e.label),
                subtitle: Text(_fmt(e.createdAt)),
              );
            },
          );
        },
      ),
    );
  }
}
