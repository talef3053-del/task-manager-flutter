import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/recurrence_rule.dart';
import '../models/task.dart';
import '../utils/date_utils.dart';

/// Schedules local reminders. Only this file talks to the notification plugin.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Phase 7 will connect this to the saved setting.
  bool soundEnabled = true;

  static const int _testId = 999999999;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;

    // Time zones: needed so "18:00" means 18:00 on the phone's clock.
    tzdata.initializeTimeZones();
    try {
      // Older versions return a String, newer ones an object with .identifier
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      final String name = info is String ? info : info.identifier as String;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('Could not read device time zone: $e');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Asks for the Android 13+ notification permission and, if needed,
  /// opens the exact-alarm setting.
  Future<void> requestPermissions() async {
    if (!_ready) return;
    final android = _android;
    if (android == null) return;
    await android.requestNotificationsPermission();
    final canExact = await android.canScheduleExactNotifications() ?? false;
    if (!canExact) await android.requestExactAlarmsPermission();
  }

  Future<AndroidScheduleMode> _mode() async {
    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// A channel's sound cannot change after creation on Android 8+,
  /// so the sound and silent options use two separate channels.
  NotificationDetails _details() =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          soundEnabled ? 'task_reminders' : 'task_reminders_silent',
          soundEnabled ? 'Task reminders' : 'Task reminders (silent)',
          channelDescription: 'Reminders at the due time of your tasks',
          importance: Importance.high,
          priority: Priority.high,
          playSound: soundEnabled,
          enableVibration: true,
        ),
      );

  /// Cancels everything and schedules again from the current task list.
  Future<void> rescheduleAll(List<Task> tasks) async {
    if (!_ready) return;
    await _plugin.cancelAll();

    final mode = await _mode();
    final now = tz.TZDateTime.now(tz.local);

    for (final t in tasks) {
      if (t.id == null) continue;
      final base = t.id! * 10;
      final rule = t.recurrence;

      if (t.isRepeating && rule != null) {
        if (rule.type == RepeatType.daily) {
          await _schedule(base, t, _next(t, now, (_) => true), mode,
              DateTimeComponents.time);
        } else {
          for (final wd in rule.weekdays) {
            await _schedule(base + wd, t, _next(t, now, (d) => d == wd), mode,
                DateTimeComponents.dayOfWeekAndTime);
          }
        }
      } else if (!t.isCompleted) {
        final when = tz.TZDateTime.from(t.dueDateTime, tz.local);
        if (when.isAfter(now)) {
          await _schedule(base, t, when, mode, null);
        }
      }
    }
  }

  Future<void> _schedule(int id,
      Task t,
      tz.TZDateTime when,
      AndroidScheduleMode mode,
      DateTimeComponents? repeat,) {
    final due = AppDateUtils.formatTime(t.dueTime.hour, t.dueTime.minute);
    return _plugin.zonedSchedule(
      id: id,
      title: t.title,
      body: t.description.isEmpty ? 'Due at $due' : t.description,
      scheduledDate: when,
      notificationDetails: _details(),
      androidScheduleMode: mode,
      matchDateTimeComponents: repeat,
    );
  }

  /// First moment at the task's time that is in the future, on or after the
  /// task's start date, and on an allowed weekday.
  tz.TZDateTime _next(Task t, tz.TZDateTime now,
      bool Function(int weekday) allowed) {
    final h = t.dueTime.hour;
    final m = t.dueTime.minute;

    var d = tz.TZDateTime(
        tz.local, t.dueDate.year, t.dueDate.month, t.dueDate.day, h, m);
    final todayAt = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (d.isBefore(todayAt)) d = todayAt;

    while (!d.isAfter(now) || !allowed(d.weekday)) {
      d = tz.TZDateTime(tz.local, d.year, d.month, d.day + 1, h, m);
    }
    return d;
  }

  /// Temporary helper: a reminder 10 seconds from now.
  Future<void> scheduleTest() async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      id: _testId,
      title: 'Test reminder',
      body: 'Notifications are working.',
      scheduledDate:
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      notificationDetails: _details(),
      androidScheduleMode: await _mode(),
    );
  }
}