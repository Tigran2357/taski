import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Wraps flutter_local_notifications for the task timer:
/// a low-priority ongoing countdown, and a high-priority alert (sound +
/// vibration) scheduled for the deadline.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Channel IDs are versioned: Android locks a channel's importance/sound at
  // creation, so bumping the suffix forces fresh settings without a reinstall.
  static const _countdownChannelId = 'task_timer_countdown_v2';
  static const _alertChannelId = 'task_timer_alert_v2';
  static const _friendChannelId = 'taski_friends_v1';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to UTC if the device timezone can't be resolved.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    final android_ = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android_?.createNotificationChannel(
      const AndroidNotificationChannel(
        _countdownChannelId,
        'Task timer countdown',
        description: 'Live countdown while a task timer is running',
        importance: Importance.low,
        enableVibration: false,
        playSound: false,
      ),
    );
    await android_?.createNotificationChannel(
      AndroidNotificationChannel(
        _alertChannelId,
        'Task timer finished',
        description: 'Alert when a task timer runs out',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 400]),
      ),
    );
    await android_?.createNotificationChannel(
      const AndroidNotificationChannel(
        _friendChannelId,
        'Friend requests',
        description: 'New friend requests',
        importance: Importance.high,
      ),
    );
  }

  Future<void> showFriendRequest(String senderUsername) async {
    await _plugin.show(
      id: 'friend_req:$senderUsername'.hashCode & 0x7fffffff,
      title: 'New friend request',
      body: '$senderUsername wants to be your friend',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _friendChannelId,
          'Friend requests',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  int _countdownId(String taskId) => taskId.hashCode & 0x7fffffff;
  int _alertId(String taskId) => '$taskId:alert'.hashCode & 0x7fffffff;
  int _startId(String taskId) => '$taskId:start'.hashCode & 0x7fffffff;

  /// Shows / updates the ongoing countdown for a task.
  Future<void> showCountdown(String taskId, String title, String body) async {
    await _plugin.show(
      id: _countdownId(taskId),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _countdownChannelId,
          'Task timer countdown',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          showWhen: false,
        ),
        iOS: DarwinNotificationDetails(presentSound: false),
      ),
    );
  }

  /// Schedules the "time's up" alert (sound + short vibration) at [deadline].
  Future<void> scheduleDeadline(
    String taskId,
    String title,
    DateTime deadline,
  ) async {
    final when = tz.TZDateTime.from(deadline, tz.local);
    final vibration = Int64List.fromList([0, 400]);
    await _plugin.zonedSchedule(
      id: _alertId(taskId),
      title: "Time's up!",
      body: title,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          'Task timer finished',
          importance: Importance.max,
          priority: Priority.high,
          vibrationPattern: vibration,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Schedules a "task started" alert at [start] for a timer set to begin
  /// in the future. No-op effect if [start] is already in the past.
  Future<void> scheduleStart(
    String taskId,
    String title,
    DateTime start,
  ) async {
    if (!start.isAfter(DateTime.now())) return;
    final when = tz.TZDateTime.from(start, tz.local);
    await _plugin.zonedSchedule(
      id: _startId(taskId),
      title: 'Task started',
      body: title,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          'Task timer finished',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelCountdown(String taskId) =>
      _plugin.cancel(id: _countdownId(taskId));

  Future<void> cancelAlert(String taskId) =>
      _plugin.cancel(id: _alertId(taskId));

  Future<void> cancelStart(String taskId) =>
      _plugin.cancel(id: _startId(taskId));

  Future<void> cancel(String taskId) async {
    await cancelCountdown(taskId);
    await cancelAlert(taskId);
    await cancelStart(taskId);
  }
}
