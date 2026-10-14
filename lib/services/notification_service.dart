import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants.dart';
import 'prefs_service.dart';

/// Daily local notifications for workout time and water.
///
/// Everything is scheduled on the device. No push service is involved.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const String _workoutChannelId = 'trainerapp_workout';
  static const String _waterChannelId = 'trainerapp_water';

  static Future<NotificationService> create() async {
    final service = NotificationService(FlutterLocalNotificationsPlugin());
    await service._init();
    return service;
  }

  Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } on Object {
      // Fall back to UTC. Reminders still fire, just anchored to UTC, which is
      // better than no reminders at all.
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } on Object {
        return;
      }
    }

    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } on Object {
      _ready = false;
    }
  }

  /// Ask for the Android 13+ notification permission. Returns false when the
  /// user declines, and the caller leaves reminders switched off.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Replace the workout reminder with one at the configured time.
  Future<void> scheduleWorkoutReminder({
    required ReminderSetting setting,
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(Entitlements.workoutNotificationId);
    if (!_ready || !setting.enabled) return;

    await _scheduleDaily(
      id: Entitlements.workoutNotificationId,
      hour: setting.hour,
      minute: setting.minute,
      title: title,
      body: body,
      channelId: _workoutChannelId,
      channelName: 'Workout reminders',
    );
  }

  /// Replace the water reminders with a set spread through the user's day.
  ///
  /// The first fires at the configured time and the rest follow at even
  /// intervals until roughly bedtime, so a single setting covers the whole day.
  Future<void> scheduleWaterReminders({
    required ReminderSetting setting,
    required String title,
    required String body,
  }) async {
    for (var i = 0; i < Entitlements.waterReminderCount; i++) {
      await _plugin.cancel(Entitlements.waterNotificationIdBase + i);
    }
    if (!_ready || !setting.enabled) return;

    // Spread the reminders over a 12 hour waking window.
    const spanHours = 12;
    final stepMinutes = (spanHours * 60) ~/ Entitlements.waterReminderCount;

    for (var i = 0; i < Entitlements.waterReminderCount; i++) {
      final total = setting.hour * 60 + setting.minute + stepMinutes * i;
      final hour = (total ~/ 60) % 24;
      final minute = total % 60;
      await _scheduleDaily(
        id: Entitlements.waterNotificationIdBase + i,
        hour: hour,
        minute: minute,
        title: title,
        body: body,
        channelId: _waterChannelId,
        channelName: 'Water reminders',
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOf(hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on Object {
      // Exact-alarm or notification permission may be denied. The reminder is
      // simply not scheduled; the rest of the app is unaffected.
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } on Object {
      // Nothing scheduled.
    }
  }
}
