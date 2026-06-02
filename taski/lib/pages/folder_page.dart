import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:taski/models/folder.dart';
import 'package:taski/models/task.dart';
import 'package:taski/services/notification_service.dart';
import 'package:taski/services/tasks_repository.dart';
import 'package:taski/theme/task_colors.dart';
import 'package:taski/widgets/bouncy_button.dart';
import 'package:taski/widgets/confirm_dialog.dart';
import 'package:taski/widgets/theme_toggle.dart';
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
  // Tasks for this folder, kept live from the local SQLite watch stream.
  List<Task> _tasks = [];
  StreamSubscription<List<Task>>? _sub;
  // Guards against the ticker re-completing a task before the stream catches up.
  final Set<String> _completing = {};
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Seed with whatever the folder already had, then keep it live.
    _tasks = widget.folder.tasks;
    _sub = _repo.watch(widget.folder.id).listen((tasks) {
      if (mounted) setState(() => _tasks = tasks);
    });
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
    for (final t in _tasks) {
      if (t.isDone(now) && !_completing.contains(t.id)) {
        _completeFromTimer(t);
      }
    }
  }

  Future<void> _completeFromTimer(Task task) async {
    _completing.add(task.id);
    _shownCountdowns.remove(task.id);
    await _notif.cancelCountdown(task.id);
    await _repo.setCompleted(task.id, true);
    await _repo.clearTimer(task.id);
    _completing.remove(task.id);
  }

  @override
  void dispose() {
    _sub?.cancel();
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
    for (final t in _tasks) {
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
    void save() {
      final text = controller.text.trim();
      if (text.isNotEmpty) Navigator.pop(context, text);
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        insetAnimationDuration: const Duration(milliseconds: 250),
        insetAnimationCurve: Curves.easeOutCubic,
        child: ConstrainedBox(
          // Cap height so a 26-line task never overflows the screen.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 26,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(hintText: 'Task'),
                    ),
                  ),
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
      ),
    );
  }

  // Mutations write to local SQLite; the watch stream refreshes the UI.
  Future<void> _addTask() async {
    final title = await _prompt('New task');
    if (title == null) return;
    await _repo.create(folderId: widget.folder.id, title: title);
  }

  Future<void> _renameTask(Task task) async {
    final title = await _prompt('Rename task', initial: task.title);
    if (title == null) return;
    await _repo.rename(task.id, title);
  }

  Future<void> _deleteTask(Task task) async {
    await _repo.delete(task.id);
    await _notif.cancel(task.id);
    _shownCountdowns.remove(task.id);
  }

  Future<void> _toggleTask(Task task) async {
    await _repo.setCompleted(task.id, !task.completed);
  }

  Future<void> _setColor(Task task, String? color) async {
    await _repo.setColor(task.id, color);
  }

  Future<void> _setTimer(Task task) async {
    final result = await showDialog<({DateTime start, DateTime end})>(
      context: context,
      builder: (_) => const TimerSetupDialog(),
    );
    if (result == null) return;
    await _repo.setTimer(task.id, result.start, result.end);
    await _notif.scheduleStart(task.id, task.title, result.start);
    await _notif.scheduleDeadline(task.id, task.title, result.end);
  }

  Future<void> _pauseTimer(Task task) async {
    final remaining = task.remaining().inSeconds;
    await _repo.pauseTimer(task.id, remaining);
    await _notif.cancelAlert(task.id);
  }

  Future<void> _resumeTimer(Task task) async {
    final total = task.timerTotalSeconds ?? 0;
    final remaining = task.timerRemainingSeconds ?? 0;
    final now = DateTime.now();
    final start = now.subtract(Duration(seconds: total - remaining));
    final end = now.add(Duration(seconds: remaining));
    await _repo.resumeTimer(task.id, start, end);
    await _notif.scheduleDeadline(task.id, task.title, end);
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
          if (task.isPending())
            ListTile(
              leading: const Icon(Icons.cancel_schedule_send, color: Colors.red),
              title: const Text('Cancel schedule', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _resetTimer(task);
              },
            ),
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
    final tasks = _tasks;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: ThemeToggleTap(
          child: Text(
            widget.folder.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        elevation: 0.0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
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
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final hasCustomColor = base != null;
                // On a coloured banner we stick to light-mode text (dark on
                // pastel) for legibility, regardless of theme.
                final completedColor = hasCustomColor
                    ? Colors.grey
                    : (isDark ? Colors.white : Colors.grey);
                final textColor = active
                    ? Colors.white
                    : t.completed
                    ? completedColor
                    : (hasCustomColor ? Colors.black : null);
                final showPause = t.isRunning(now);
                final isPending = t.isPending(now);
                // Border = a darker shade of the current banner background.
                final bannerColor = active
                    ? kTimerRed
                    : (base ?? Theme.of(context).cardColor);
                final borderColor = darken(bannerColor, 0.25);
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
                    child: isPending && !t.completed
                        ? Stack(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 16,
                                  right: 52,
                                ),
                                leading: Checkbox(
                                  value: t.completed,
                                  onChanged: (_) => _toggleTask(t),
                                  side: BorderSide(color: borderColor, width: 2),
                                ),
                                title: Text(
                                  t.title,
                                  style: TextStyle(
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: _ScheduledChip(
                                  start: t.timerStart!,
                                  hasCustomColor: hasCustomColor,
                                  isDark: isDark,
                                  isTall: '\n'.allMatches(t.title).length >= 3,
                                ),
                              ),
                            ],
                          )
                        : ListTile(
                      leading: active
                          ? null
                          : Checkbox(
                              value: t.completed,
                              onChanged: (_) => _toggleTask(t),
                              side: BorderSide(color: borderColor, width: 2),
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
                      trailing: t.completed
                          ? null
                          : BouncyIconButton(
                              icon: showPause
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: active
                                  ? Colors.white
                                  : Colors.lightBlueAccent,
                              borderColor: borderColor,
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

/// Pill shown when a timer is scheduled but not yet running.
/// Short tasks: compact 2-char label (or icon+label).
/// 3+ line tasks: Column (icon on top, full label below) — same look as screenshot.
class _ScheduledChip extends StatelessWidget {
  final DateTime start;
  final bool hasCustomColor;
  final bool isDark;
  final bool isTall;
  const _ScheduledChip({
    required this.start,
    required this.hasCustomColor,
    required this.isDark,
    this.isTall = false,
  });

  // Short label for compact layout.
  String _shortLabel() {
    final diff = start.difference(DateTime.now());
    if (diff.inMinutes < 10) return '${diff.inMinutes.clamp(0, 9)}m';
    if (diff.inMinutes < 60) return '<1h';
    return '${diff.inHours}h';
  }

  // Full label for tall layout: "in 1h 57m" style.
  String _fullLabel() {
    final diff = start.difference(DateTime.now());
    String two(int n) => n.toString().padLeft(2, '0');
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m > 0 ? 'in ${h}h ${two(m)}m' : 'in ${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final fg = hasCustomColor ? Colors.black87 : Colors.white;
    final bg = hasCustomColor
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.13);
    final textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: fg,
    );

    // Tall tasks: Column (icon top, label below) rotated quarterTurns:1
    // so it reads top→bottom like the screenshot.
    // Short tasks: compact rotated Row.
    final Widget content;
    if (isTall) {
      content = RotatedBox(
        quarterTurns: 3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: fg),
            const SizedBox(height: 4),
            Text(_fullLabel(), style: textStyle),
          ],
        ),
      );
    } else {
      final label = _shortLabel();
      final short = label.length <= 2;
      content = RotatedBox(
        quarterTurns: 3,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!short) ...[
              Icon(Icons.schedule_rounded, size: 12, color: fg),
              const SizedBox(width: 3),
            ],
            Text(label, style: textStyle),
          ],
        ),
      );
    }

    // All corners rounded to match the card's 12px border radius.
    const radius = BorderRadius.only(
      topRight: Radius.circular(12),
      bottomRight: Radius.circular(12),
    );
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: fg.withValues(alpha: 0.2), width: 0.8),
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}
