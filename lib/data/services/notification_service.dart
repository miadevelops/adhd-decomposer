import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Service for managing local notifications
/// 
/// iOS Setup Requirements (document for later implementation):
/// 1. Add to ios/Runner/AppDelegate.swift:
///    ```swift
///    if #available(iOS 10.0, *) {
///      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
///    }
///    ```
/// 2. Add to Info.plist:
///    - UIBackgroundModes: fetch, remote-notification
/// 3. Request permissions in AppDelegate for iOS < 10
/// 4. Handle notification tap in AppDelegate for deep linking
class NotificationService {
  static const String _boxName = 'notification_settings';
  
  // Settings keys
  static const String keyNotificationsEnabled = 'notificationsEnabled';
  static const String keyReminderHour = 'reminderHour';
  static const String keyReminderMinute = 'reminderMinute';
  static const String keyGentleNudgeEnabled = 'gentleNudgeEnabled';
  static const String keyLastTaskActivityTime = 'lastTaskActivityTime';
  static const String keyHasActiveTask = 'hasActiveTask';
  static const String keyActiveTaskId = 'activeTaskId';
  
  // Notification IDs
  static const int dailyReminderId = 1;
  static const int unfinishedTaskId = 2;
  static const int streakReminderId = 3;
  
  // Notification channels
  static const String channelId = 'tiny_steps_reminders';
  static const String channelName = 'Reminders';
  static const String channelDescription = 'Gentle reminders to keep you on track';
  
  // Deep link payloads
  static const String payloadHome = 'home';
  static const String payloadExecute = 'execute';
  static const String payloadStats = 'stats';
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Box<dynamic>? _box;
  
  // Callback for handling notification taps
  static Function(String?)? onNotificationTap;
  
  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone. tz.local defaults to UTC, which makes daily
    // reminders fire at the wrong wall-clock time and drift across DST.
    tz.initializeTimeZones();
    if (!kIsWeb) {
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (e) {
        debugPrint('NotificationService: could not resolve local timezone: $e');
      }
    }
    
    // Open settings box
    _box = await Hive.openBox(_boxName);
    
    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('app_icon_notification');
    
    // iOS settings - request permissions later
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    // Create notification channel for Android
    await _createNotificationChannel();
  }
  
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.defaultImportance,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('Notification tapped with payload: $payload');
    onNotificationTap?.call(payload);
  }
  
  Box<dynamic> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('NotificationService not initialized. Call initialize() first.');
    }
    return _box!;
  }
  
  // Settings getters/setters
  bool get notificationsEnabled => _safeBox.get(keyNotificationsEnabled, defaultValue: false);
  set notificationsEnabled(bool value) => _safeBox.put(keyNotificationsEnabled, value);
  
  int get reminderHour => _safeBox.get(keyReminderHour, defaultValue: 9);
  set reminderHour(int value) => _safeBox.put(keyReminderHour, value);
  
  int get reminderMinute => _safeBox.get(keyReminderMinute, defaultValue: 0);
  set reminderMinute(int value) => _safeBox.put(keyReminderMinute, value);
  
  bool get gentleNudgeEnabled => _safeBox.get(keyGentleNudgeEnabled, defaultValue: true);
  set gentleNudgeEnabled(bool value) => _safeBox.put(keyGentleNudgeEnabled, value);
  
  DateTime? get lastTaskActivityTime {
    final millis = _safeBox.get(keyLastTaskActivityTime);
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }
  set lastTaskActivityTime(DateTime? value) {
    _safeBox.put(keyLastTaskActivityTime, value?.millisecondsSinceEpoch);
  }
  
  bool get hasActiveTask => _safeBox.get(keyHasActiveTask, defaultValue: false);
  set hasActiveTask(bool value) => _safeBox.put(keyHasActiveTask, value);
  
  String? get activeTaskId => _safeBox.get(keyActiveTaskId);
  set activeTaskId(String? value) => _safeBox.put(keyActiveTaskId, value);
  
  /// Request notification permissions
  /// Returns true if permissions were granted
  Future<bool> requestPermissions() async {
    // Request Android permissions (Android 13+)
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    
    // Request iOS permissions
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    
    return true;
  }
  
  /// Enable notifications (requests permissions if needed)
  Future<bool> enableNotifications() async {
    final granted = await requestPermissions();
    if (granted) {
      notificationsEnabled = true;
      await scheduleDailyReminder();
    }
    return granted;
  }
  
  /// Disable all notifications
  Future<void> disableNotifications() async {
    notificationsEnabled = false;
    await cancelAllNotifications();
  }
  
  /// Set the daily reminder time
  Future<void> setReminderTime(int hour, int minute) async {
    reminderHour = hour;
    reminderMinute = minute;
    
    if (notificationsEnabled) {
      await scheduleDailyReminder();
    }
  }
  
  /// Schedule the daily reminder notification
  Future<void> scheduleDailyReminder() async {
    if (!notificationsEnabled) return;
    
    await _notifications.cancel(dailyReminderId);
    
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminderHour,
      reminderMinute,
    );
    
    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month,
          now.day + 1, reminderHour, reminderMinute);
    }
    
    await _notifications.zonedSchedule(
      dailyReminderId,
      '🌟 Time to take tiny steps!',
      'What task can you break down today?',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payloadHome,
    );
    
    debugPrint('Scheduled daily reminder for ${scheduledDate.hour}:${scheduledDate.minute}');
  }
  
  /// Schedule the unfinished task reminder (2 hours after last activity)
  Future<void> scheduleUnfinishedTaskReminder(String taskId) async {
    if (!notificationsEnabled || !gentleNudgeEnabled) return;
    
    await _notifications.cancel(unfinishedTaskId);
    
    // Update tracking
    hasActiveTask = true;
    activeTaskId = taskId;
    lastTaskActivityTime = DateTime.now();
    
    final reminderTime = DateTime.now().add(const Duration(hours: 2));
    
    await _notifications.zonedSchedule(
      unfinishedTaskId,
      '💭 You have an unfinished task',
      'Ready to take the next tiny step?',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payloadExecute,
    );
    
    debugPrint('Scheduled unfinished task reminder for 2 hours from now');
  }
  
  /// Update task activity (resets the 2-hour timer)
  Future<void> updateTaskActivity() async {
    if (!notificationsEnabled || !gentleNudgeEnabled || !hasActiveTask) return;
    
    lastTaskActivityTime = DateTime.now();
    
    // Reschedule the reminder
    if (activeTaskId != null) {
      await scheduleUnfinishedTaskReminder(activeTaskId!);
    }
  }
  
  /// Clear the unfinished task reminder (task completed or cancelled)
  Future<void> clearUnfinishedTaskReminder() async {
    await _notifications.cancel(unfinishedTaskId);
    hasActiveTask = false;
    activeTaskId = null;
    lastTaskActivityTime = null;
  }
  
  /// Schedule streak reminder for the morning
  Future<void> scheduleStreakReminder(int currentStreak) async {
    if (!notificationsEnabled || currentStreak < 2) return;
    
    await _notifications.cancel(streakReminderId);
    
    // 8:30 AM tomorrow, local wall-clock time
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 8, 30);
    
    await _notifications.zonedSchedule(
      streakReminderId,
      '🔥 Great streak! Keep it going!',
      'You\'re on a $currentStreak day streak. Don\'t break the chain!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payloadStats,
    );
    
    debugPrint('Scheduled streak reminder for tomorrow 8:30 AM');
  }
  
  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    hasActiveTask = false;
    activeTaskId = null;
  }
  
  /// Show an immediate test notification
  Future<void> showTestNotification() async {
    await _notifications.show(
      999,
      '✅ Notifications working!',
      'You\'ll receive gentle reminders to keep you on track.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payloadHome,
    );
  }
  
  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _notifications.pendingNotificationRequests();
  }
}
