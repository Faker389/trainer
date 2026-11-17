import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dates.dart';
import 'store.dart';

/// Weekly "Dziś Push" reminders for every non-rest day of the split.
/// Android only; no-ops elsewhere. Rescheduled (debounced) whenever the split changes.
class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;

  /// Notification hour; reminders fire weekly at this time on each training day.
  static const hour = 10, minute = 0;

  static Future<void> init() async {
    if (_ready || kIsWeb || !Platform.isAndroid) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
          settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  /// Schedules one weekly notification per non-rest day, named after the day's workout.
  static Future<void> reschedule(AppStore store) async {
    if (!_ready) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () async {
      try {
        await _plugin.cancelAll();
        const details = NotificationDetails(
          android: AndroidNotificationDetails(
            'training_plan',
            'Trening',
            channelDescription: 'Przypomnienia o treningu z planu tygodniowego',
            importance: Importance.defaultImportance,
          ),
        );
        for (var wd = 1; wd <= 7; wd++) {
          final day = store.splitFor(wd);
          if (day.isRest) continue;
          final name = day.name.isEmpty ? weekdayNames[wd - 1] : day.name;
          await _plugin.zonedSchedule(
            id: wd,
            title: 'Trening: $name',
            body: 'Dziś w planie ${day.exerciseIds.length} ćw. — do dzieła!',
            scheduledDate: _nextWeekdayAt(wd),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      } catch (e) {
        debugPrint('Rescheduling reminders failed: $e');
      }
    });
  }

  static tz.TZDateTime _nextWeekdayAt(int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (d.weekday != weekday || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
}
