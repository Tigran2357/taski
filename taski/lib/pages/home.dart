import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:taski/models/folder.dart';
import 'package:taski/models/task.dart';
import 'package:taski/pages/folder_page.dart';
import 'package:taski/pages/friends_page.dart';
import 'package:taski/services/auth_service.dart';
import 'package:taski/services/folders_repository.dart';
import 'package:taski/services/friends_service.dart';
import 'package:taski/services/notification_service.dart';
import 'package:taski/theme/task_colors.dart';
import 'package:taski/widgets/confirm_dialog.dart';
import 'package:taski/widgets/theme_toggle.dart';
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
  final _friends = FriendsService();
  // Live stream of folders (+ their tasks) from local SQLite.
  late final Stream<List<Folder>> _foldersStream = _repo.watchAll();
  bool _hasPendingRequests = false;
  final Set<String> _knownRequestIds = {};
  Timer? _ticker;
  Timer? _friendsPoller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
    // Rebuild every second so a folder's timer fill animates.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Poll for incoming friend requests; first call seeds the known set so we
    // don't spam notifications for already-pending ones at launch.
    _refreshPending(initial: true);
    _friendsPoller = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshPending(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _friendsPoller?.cancel();
    super.dispose();
  }

  Future<void> _refreshPending({bool initial = false}) async {
    try {
      final items = await _friends.pending();
      final newIds = items.map((r) => r.id).toSet();
      if (!initial) {
        for (final r in items) {
          if (!_knownRequestIds.contains(r.id)) {
            await NotificationService.instance.showFriendRequest(
              r.senderUsername,
            );
          }
        }
      }
      _knownRequestIds
        ..clear()
        ..addAll(newIds);
      if (mounted) setState(() => _hasPendingRequests = items.isNotEmpty);
    } catch (_) {
      // Ignore transient errors; we'll try again on the next poll.
    }
  }


  Future<void> _welcome() async {
    final name = await _auth.currentName();
    if (!mounted) return;
    showTopToast(context, 'Welcome ${name ?? ''}'.trim());
  }

  Future<String?> _prompt(String title, {String? initial}) {
    final controller = TextEditingController(text: initial);
    void save() {
      final text = controller.text.trim();
      if (text.isNotEmpty) Navigator.pop(context, text);
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        insetAnimationDuration: const Duration(milliseconds: 250),
        insetAnimationCurve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Folder name'),
                onSubmitted: (_) => save(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  TextButton(onPressed: save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mutations just write to local SQLite; the watch stream updates the UI.
  Future<void> _addFolder() async {
    final name = await _prompt('New folder');
    if (name == null) return;
    await _repo.create(name);
  }

  Future<void> _renameFolder(Folder folder) async {
    final name = await _prompt('Rename folder', initial: folder.name);
    if (name == null) return;
    await _repo.rename(folder.id, name);
  }

  Future<void> _deleteFolder(Folder folder) async {
    await _repo.delete(folder.id);
  }

  Future<void> _setColor(Folder folder, String? color) async {
    await _repo.setColor(folder.id, color);
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
      appBar: AppBar(
        title: const ThemeToggleTap(
          child: Text(
            'TaskLand',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
        actions: [
          Badge(
            isLabelVisible: _hasPendingRequests,
            backgroundColor: Colors.green,
            smallSize: 9,
            alignment: AlignmentDirectional.topEnd,
            offset: const Offset(-10, 8),
            child: IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Friends',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsPage()),
                );
                // After returning, refresh badge state.
                _refreshPending();
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Folder>>(
        stream: _foldersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final folders = snapshot.data!;
          if (folders.isEmpty) {
            return const Center(
              child: Text('No folders yet. Tap + to add one.'),
            );
          }
          return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: folders.length,
              itemBuilder: (_, i) {
                final f = folders[i];
                final done = f.tasks.where((t) => t.completed).length;
                final base = f.color != null ? colorFromHex(f.color!) : null;
                final timerTask = f.activeTimerTask;
                final active = timerTask != null;
                final progress = active ? timerTask.timerProgress() : null;
                final hasCustomColor = base != null;
                // Coloured folders keep light-mode (dark) text so the pastel
                // background stays readable even in dark mode.
                final textColor = active
                    ? Colors.white
                    : (hasCustomColor ? Colors.black : null);
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
                          _SegmentedBar(
                            tasks: f.tasks,
                            isActive: active,
                            hasCustomColor: hasCustomColor,
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

/// A row of small rounded segments — one per task — filled if the task is done.
class _SegmentedBar extends StatelessWidget {
  final List<Task> tasks;
  final bool isActive;
  final bool hasCustomColor;

  const _SegmentedBar({
    required this.tasks,
    required this.isActive,
    required this.hasCustomColor,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox(height: 6);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color doneColor;
    final Color emptyColor;
    if (isActive) {
      doneColor = Colors.white;
      emptyColor = Colors.white24;
    } else if (hasCustomColor) {
      doneColor = Colors.black54;
      emptyColor = Colors.black12;
    } else if (isDark) {
      doneColor = Colors.white;
      emptyColor = Colors.white24;
    } else {
      doneColor = Theme.of(context).colorScheme.primary;
      emptyColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.18);
    }
    return Row(
      children: [
        for (int i = 0; i < tasks.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              decoration: BoxDecoration(
                color: tasks[i].completed ? doneColor : emptyColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
