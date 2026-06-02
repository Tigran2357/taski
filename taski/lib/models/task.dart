DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

int? _parseInt(dynamic value) => (value as num?)?.toInt();

/// Supabase returns real bools; local SQLite returns 0/1 ints. Accept both.
bool _parseBool(dynamic value) => value == true || value == 1;

class Task {
  final String id;
  final String folderId;
  String title;
  bool completed;

  /// Hex color for the task banner, e.g. '#90CAF9'. Null = default card color.
  String? color;

  /// Timer state. [timerTotalSeconds] null = no timer set.
  /// While running, [timerEnd] holds the deadline. While paused,
  /// [timerRemainingSeconds] holds what's left and [timerEnd] is null.
  int? timerTotalSeconds;
  DateTime? timerStart;
  DateTime? timerEnd;
  bool timerPaused;
  int? timerRemainingSeconds;

  Task({
    required this.id,
    required this.folderId,
    required this.title,
    this.completed = false,
    this.color,
    this.timerTotalSeconds,
    this.timerStart,
    this.timerEnd,
    this.timerPaused = false,
    this.timerRemainingSeconds,
  });

  bool get hasTimer => timerTotalSeconds != null;
  bool get isPaused => hasTimer && timerPaused;

  /// Set but scheduled to start in the future.
  bool isPending([DateTime? now]) {
    if (!hasTimer || isPaused || timerStart == null) return false;
    return (now ?? DateTime.now()).isBefore(timerStart!);
  }

  bool isRunning([DateTime? now]) {
    if (!hasTimer || isPaused || timerStart == null || timerEnd == null) {
      return false;
    }
    final n = now ?? DateTime.now();
    return !n.isBefore(timerStart!) && n.isBefore(timerEnd!);
  }

  bool isDone([DateTime? now]) {
    if (!hasTimer || isPaused || timerEnd == null) return false;
    return !(now ?? DateTime.now()).isBefore(timerEnd!);
  }

  /// Red banner shows while a started timer is running or paused.
  bool isTimerVisible([DateTime? now]) => isRunning(now) || isPaused;

  /// 0.0 at the start, 1.0 at the deadline. Drives the colour fill.
  double timerProgress([DateTime? now]) {
    final total = timerTotalSeconds;
    if (total == null || total <= 0) return 0;
    if (isPaused) {
      final remaining = timerRemainingSeconds ?? 0;
      return (1 - remaining / total).clamp(0.0, 1.0);
    }
    if (timerStart == null) return 0;
    final elapsed = (now ?? DateTime.now()).difference(timerStart!).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Duration remaining([DateTime? now]) {
    if (!hasTimer) return Duration.zero;
    if (isPaused) return Duration(seconds: timerRemainingSeconds ?? 0);
    if (timerEnd == null) return Duration.zero;
    final r = timerEnd!.difference(now ?? DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'] as String,
    folderId: map['folder_id'] as String,
    title: map['title'] as String,
    completed: _parseBool(map['completed']),
    color: map['color'] as String?,
    timerTotalSeconds: _parseInt(map['timer_total_seconds']),
    timerStart: _parseDate(map['timer_start']),
    timerEnd: _parseDate(map['timer_end']),
    timerPaused: _parseBool(map['timer_paused']),
    timerRemainingSeconds: _parseInt(map['timer_remaining_seconds']),
  );
}
