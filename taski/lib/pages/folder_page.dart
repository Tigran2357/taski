import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:taski/models/folder.dart';
import 'package:taski/models/task.dart';
import 'package:taski/services/notification_service.dart';
import 'package:taski/services/tasks_repository.dart';
import 'package:taski/theme/task_colors.dart';
import 'package:taski/widgets/confirm_dialog.dart';
import 'package:taski/widgets/timer_card.dart';
import 'package:taski/widgets/timer_setup_dialog.dart';

class FolderPage extends StatefulWidget {
  final Folder folder;
  const FolderPage({super.key, required this.folder});

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  final _repo = TasksRepository();
  final _notif = NotificationService.instance;
  final Set<String> _shownCountdowns = {};
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Rebuild every second so running timers animate their fill, and refresh
    // the live countdown notifications.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _syncNotifications();
      _completeFinishedTimers();
    });
  }

  /// When a task's timer runs out, mark it complete and clear the spent timer.
  void _completeFinishedTimers() {
    final now = DateTime.now();
    for (final t in widget.folder.tasks) {
      if (t.isDone(now)) _completeFromTimer(t);
    }
  }

  Future<void> _completeFromTimer(Task task) async {
    setState(() {
      task.completed = true;
      task.timerTotalSeconds = null;
      task.timerStart = null;
      task.timerEnd = null;
      task.timerPaused = false;
      task.timerRemainingSeconds = null;
    });
    _shownCountdowns.remove(task.id);
    await _notif.cancelCountdown(task.id);
    await _repo.setCompleted(task.id, true);
    await _repo.clearTimer(task.id);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// Keeps each task's ongoing countdown notification in sync with its state.
  void _syncNotifications() {
    final now = DateTime.now();
    for (final t in widget.folder.tasks) {
      if (t.isRunning(now)) {
        _notif.showCountdown(t.id, t.title, '${_fmtDuration(t.remaining(now))} left');
        _shownCountdowns.add(t.id);
      } else if (t.isPaused) {
        _notif.showCountdown(
          t.id,
          t.title,
          'Paused • ${_fmtDuration(t.remaining())} left',
        );
        _shownCountdowns.add(t.id);
      } else if (_shownCountdowns.remove(t.id)) {
        _notif.cancelCountdown(t.id);
      }
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
    final task = await _repo.create(folderId: widget.folder.id, title: title);
    setState(() => widget.folder.tasks.add(task));
  }

  Future<void> _renameTask(Task task) async {
    final title = await _prompt('Rename task', initial: task.title);
    if (title == null) return;
    await _repo.rename(task.id, title);
    setState(() => task.title = title);
  }

  Future<void> _deleteTask(Task task) async {
    await _repo.delete(task.id);
    await _notif.cancel(task.id);
    _shownCountdowns.remove(task.id);
    setState(() => widget.folder.tasks.remove(task));
  }

  Future<void> _toggleTask(Task task) async {
    final next = !task.completed;
    setState(() => task.completed = next); // optimistic: update UI first
    try {
      await _repo.setCompleted(task.id, next);
    } catch (_) {
      if (mounted) setState(() => task.completed = !next); // revert on failure
    }
  }

  Future<void> _setColor(Task task, String? color) async {
    await _repo.setColor(task.id, color);
    setState(() => task.color = color);
  }

  Future<void> _setTimer(Task task) async {
    final result = await showDialog<({DateTime start, DateTime end})>(
      context: context,
      builder: (_) => const TimerSetupDialog(),
    );
    if (result == null) return;
    await _repo.setTimer(task.id, result.start, result.end);
    await _notif.scheduleDeadline(task.id, task.title, result.end);
    setState(() {
      task.timerTotalSeconds = result.end.difference(result.start).inSeconds;
      task.timerStart = result.start;
      task.timerEnd = result.end;
      task.timerPaused = false;
      task.timerRemainingSeconds = null;
    });
  }

  Future<void> _pauseTimer(Task task) async {
    final remaining = task.remaining().inSeconds;
    await _repo.pauseTimer(task.id, remaining);
    await _notif.cancelAlert(task.id);
    setState(() {
      task.timerPaused = true;
      task.timerRemainingSeconds = remaining;
      task.timerEnd = null;
    });
  }

  Future<void> _resumeTimer(Task task) async {
    final total = task.timerTotalSeconds ?? 0;
    final remaining = task.timerRemainingSeconds ?? 0;
    final now = DateTime.now();
    final start = now.subtract(Duration(seconds: total - remaining));
    final end = now.add(Duration(seconds: remaining));
    await _repo.resumeTimer(task.id, start, end);
    await _notif.scheduleDeadline(task.id, task.title, end);
    setState(() {
      task.timerPaused = false;
      task.timerStart = start;
      task.timerEnd = end;
      task.timerRemainingSeconds = null;
    });
  }

  void _onPlayPause(Task task) {
    final now = DateTime.now();
    if (task.isRunning(now) || task.isPending(now)) {
      _pauseTimer(task);
    } else if (task.isPaused) {
      _resumeTimer(task);
    } else {
      _setTimer(task);
    }
  }

  Future<void> _resetTimer(Task task) async {
    await _repo.clearTimer(task.id);
    await _notif.cancel(task.id);
    _shownCountdowns.remove(task.id);
    setState(() {
      task.timerTotalSeconds = null;
      task.timerStart = null;
      task.timerEnd = null;
      task.timerPaused = false;
      task.timerRemainingSeconds = null;
    });
  }

  /// Opened by holding a task. Shown centered; Delete is set apart below.
  void _showActions(Task task) {
    showDialog<void>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Task'),
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _renameTask(task);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Color'),
            onTap: () {
              Navigator.pop(context);
              _pickColor(task);
            },
          ),
          if (task.isTimerVisible())
            ListTile(
              leading: const Icon(Icons.timer_off),
              title: const Text('Reset Timer'),
              onTap: () {
                Navigator.pop(context);
                _resetTimer(task);
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
              if (await confirmDialog(context, message: 'Delete this task?')) {
                _deleteTask(task);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(Task task) async {
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
                    _setColor(task, hex);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorFromHex(hex),
                      shape: BoxShape.circle,
                      border: task.color == hex
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.black12),
                    ),
                    child: task.color == hex
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
              _setColor(task, null);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.folder.tasks;
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.folder.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: _addTask,
          ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('No tasks yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              itemBuilder: (_, i) {
                final t = tasks[i];
                final base = t.color != null ? colorFromHex(t.color!) : null;
                final active = t.isTimerVisible(now);
                final progress = active ? t.timerProgress(now) : null;
                final textColor = active
                    ? Colors.white
                    : (t.completed ? Colors.grey : null);
                final showPause = t.isRunning(now) || t.isPending(now);
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
                              instance.onLongPress = () => _showActions(t),
                        ),
                  },
                  child: TimerCard(
                    baseColor: base,
                    progress: progress,
                    child: ListTile(
                      leading: active
                          ? null
                          : Checkbox(
                              value: t.completed,
                              onChanged: (_) => _toggleTask(t),
                            ),
                      title: Text(
                        t.title,
                        style: TextStyle(
                          decoration: t.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: textColor,
                        ),
                      ),
                      trailing: IconButton(
                        iconSize: 32,
                        icon: Icon(
                          showPause
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                        color: active
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                        onPressed: () => _onPlayPause(t),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
