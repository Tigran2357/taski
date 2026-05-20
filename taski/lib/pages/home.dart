import 'package:flutter/material.dart';
import 'package:taski/models/folder.dart';
import 'package:taski/pages/folder_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Folder> _folders = [];

  Future<String?> _prompt(String title, {String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
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

  Future<void> _addFolder() async {
    final name = await _prompt('New folder');
    if (name == null) return;
    setState(() => _folders.add(Folder(name: name)));
  }

  Future<void> _renameFolder(Folder folder) async {
    final name = await _prompt('Rename folder', initial: folder.name);
    if (name == null) return;
    setState(() => folder.name = name);
  }

  void _deleteFolder(Folder folder) {
    setState(() => _folders.remove(folder));
  }

  Future<void> _openFolder(Folder folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FolderPage(folder: folder)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: _folders.isEmpty
          ? const Center(child: Text('No folders yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _folders.length,
              itemBuilder: (_, i) {
                final f = _folders[i];
                final done = f.tasks.where((t) => t.completed).length;
                return Card(
                  child: ListTile(
                    title: Text(
                      f.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: f.progress,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('$done of ${f.tasks.length} completed'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') _renameFolder(f);
                        if (v == 'delete') _deleteFolder(f);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => _openFolder(f),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFolder,
        child: const Icon(Icons.add),
      ),
    );
  }
}
