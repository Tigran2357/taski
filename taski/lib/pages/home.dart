import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:taski/models/folder.dart';
import 'package:taski/pages/folder_page.dart';
import 'package:taski/services/auth_service.dart';
import 'package:taski/services/folders_repository.dart';
import 'package:taski/theme/task_colors.dart';
import 'package:taski/widgets/confirm_dialog.dart';
import 'package:taski/widgets/timer_card.dart';
import 'package:taski/widgets/top_toast.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = FoldersRepository();
  final _auth = AuthService();
  List<Folder> _folders = [];
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
    // Rebuild every second so a folder's timer fill animates.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _welcome() async {
    final name = await _auth.currentName();
    if (!mounted) return;
    showTopToast(context, 'Welcome ${name ?? ''}'.trim());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final folders = await _repo.fetchAll();
      if (!mounted) return;
      setState(() => _folders = folders);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
    final folder = await _repo.create(name);
    setState(() => _folders.add(folder));
  }

  Future<void> _renameFolder(Folder folder) async {
    final name = await _prompt('Rename folder', initial: folder.name);
    if (name == null) return;
    await _repo.rename(folder.id, name);
    setState(() => folder.name = name);
  }

  Future<void> _deleteFolder(Folder folder) async {
    await _repo.delete(folder.id);
    setState(() => _folders.remove(folder));
  }

  Future<void> _setColor(Folder folder, String? color) async {
    await _repo.setColor(folder.id, color);
    setState(() => folder.color = color);
  }

  /// Opened by holding a folder. Shown centered; Delete is set apart below.
  void _showActions(Folder folder) {
    showDialog<void>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Folder'),
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _renameFolder(folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Color'),
            onTap: () {
              Navigator.pop(context);
              _pickColor(folder);
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              if (await confirmDialog(
                context,
                message: 'Delete this folder and its tasks?',
              )) {
                _deleteFolder(folder);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(Folder folder) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick a color'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final hex in kTaskColors)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _setColor(folder, hex);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorFromHex(hex),
                      shape: BoxShape.circle,
                      border: folder.color == hex
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.black12),
                    ),
                    child: folder.color == hex
                        ? const Icon(Icons.check, size: 20)
                        : null,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _setColor(folder, null);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
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
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            if (await confirmDialog(context, message: 'Log out of your account?')) {
              await _auth.signOut();
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
          ? const Center(child: Text('No folders yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _folders.length,
              itemBuilder: (_, i) {
                final f = _folders[i];
                final done = f.tasks.where((t) => t.completed).length;
                final base = f.color != null ? colorFromHex(f.color!) : null;
                final timerTask = f.activeTimerTask;
                final active = timerTask != null;
                final progress = active ? timerTask.timerProgress() : null;
                final textColor = active ? Colors.white : null;
                return RawGestureDetector(
                  gestures: {
                    LongPressGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer
                        >(
                          () => LongPressGestureRecognizer(
                            duration: const Duration(milliseconds: 500),
                          ),
                          (instance) =>
                              instance.onLongPress = () => _showActions(f),
                        ),
                  },
                  child: TimerCard(
                    baseColor: base,
                    progress: progress,
                    child: ListTile(
                      title: Text(
                        f.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
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
                              color: active ? Colors.white : null,
                              backgroundColor: active ? Colors.white24 : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$done of ${f.tasks.length} completed',
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                      onTap: () => _openFolder(f),
                    ),
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
