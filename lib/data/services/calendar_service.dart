import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';

/// Service for managing calendar integration and time blocking
///
/// Features:
/// - Native calendar access via device_calendar package
/// - Find free time slots for task scheduling
/// - Create calendar events with task details
/// - Settings for default calendar and reminders
class CalendarService {
  static const String _boxName = 'calendar_settings';

  // Settings keys
  static const String keyCalendarEnabled = 'calendarEnabled';
  static const String keyDefaultCalendarId = 'defaultCalendarId';
  static const String keyDefaultReminderMinutes = 'defaultReminderMinutes';

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  Box<dynamic>? _box;
  List<Calendar>? _cachedCalendars;

  /// Initialize the calendar service
  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
  }

  Box<dynamic> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
          'CalendarService not initialized. Call initialize() first.');
    }
    return _box!;
  }

  // Settings getters/setters
  bool get calendarEnabled =>
      _safeBox.get(keyCalendarEnabled, defaultValue: false);
  set calendarEnabled(bool value) => _safeBox.put(keyCalendarEnabled, value);

  String? get defaultCalendarId => _safeBox.get(keyDefaultCalendarId);
  set defaultCalendarId(String? value) =>
      _safeBox.put(keyDefaultCalendarId, value);

  int get defaultReminderMinutes =>
      _safeBox.get(keyDefaultReminderMinutes, defaultValue: 5);
  set defaultReminderMinutes(int value) =>
      _safeBox.put(keyDefaultReminderMinutes, value);

  /// Request calendar permission from the user
  /// Returns true if permission was granted
  Future<bool> requestCalendarPermission() async {
    try {
      final permissionsGranted = await _plugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data == true) {
        return true;
      }

      final result = await _plugin.requestPermissions();
      return result.isSuccess && result.data == true;
    } catch (e) {
      debugPrint('Error requesting calendar permission: $e');
      return false;
    }
  }

  /// Check if calendar permission is granted
  Future<bool> hasCalendarPermission() async {
    try {
      final result = await _plugin.hasPermissions();
      return result.isSuccess && result.data == true;
    } catch (e) {
      debugPrint('Error checking calendar permission: $e');
      return false;
    }
  }

  /// Get all available calendars on the device
  /// Returns empty list if permission not granted
  Future<List<Calendar>> getAvailableCalendars() async {
    try {
      if (!await hasCalendarPermission()) {
        return [];
      }

      final result = await _plugin.retrieveCalendars();
      if (result.isSuccess && result.data != null) {
        _cachedCalendars = result.data!.where((c) => !c.isReadOnly!).toList();
        return _cachedCalendars!;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting calendars: $e');
      return [];
    }
  }

  /// Get the default calendar (either user-selected or first available)
  Future<Calendar?> getDefaultCalendar() async {
    final calendars = await getAvailableCalendars();
    if (calendars.isEmpty) return null;

    final defaultId = defaultCalendarId;
    if (defaultId != null) {
      final calendar = calendars.firstWhere(
        (c) => c.id == defaultId,
        orElse: () => calendars.first,
      );
      return calendar;
    }

    return calendars.first;
  }

  /// Create a time block calendar event for a task
  ///
  /// Returns the created event ID, or null if creation failed
  Future<String?> createTimeBlock(
    Task task,
    DateTime startTime, {
    int? reminderMinutes,
    String? calendarId,
  }) async {
    try {
      if (!await hasCalendarPermission()) {
        debugPrint('Calendar permission not granted');
        return null;
      }

      // Get calendar to use
      String? targetCalendarId = calendarId ?? defaultCalendarId;
      if (targetCalendarId == null) {
        final defaultCal = await getDefaultCalendar();
        targetCalendarId = defaultCal?.id;
      }

      if (targetCalendarId == null) {
        debugPrint('No calendar available');
        return null;
      }

      // Calculate end time based on task duration
      final duration = Duration(minutes: task.totalEstimatedMinutes);
      final endTime = startTime.add(duration);

      // Build description with all steps
      final stepsDescription = task.steps.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final step = entry.value;
        return '$index. ${step.action} (~${step.estimatedMinutes} min)';
      }).join('\n');

      final description =
          'Task broken into ${task.steps.length} tiny steps:\n\n$stepsDescription\n\n📱 Created with Tiny Steps';

      // Create the event
      final event = Event(
        targetCalendarId,
        title: '🎯 ${task.title}',
        description: description,
        start: TZDateTime.from(startTime, local),
        end: TZDateTime.from(endTime, local),
      );

      // Add reminder
      final reminder = reminderMinutes ?? defaultReminderMinutes;
      event.reminders = [Reminder(minutes: reminder)];

      final result = await _plugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true && result?.data != null) {
        debugPrint('Created calendar event: ${result!.data}');
        return result.data;
      }

      debugPrint('Failed to create calendar event');
      return null;
    } catch (e) {
      debugPrint('Error creating time block: $e');
      return null;
    }
  }

  /// Find free time slots of the given duration within the specified range
  ///
  /// Returns up to [maxResults] suggested time slots
  Future<List<TimeSlot>> findFreeSlots(
    Duration duration,
    DateTime from,
    DateTime to, {
    int maxResults = 3,
  }) async {
    try {
      if (!await hasCalendarPermission()) {
        return _generateDefaultSlots(duration, from, to, maxResults);
      }

      // Get all calendars to check for busy times
      final calendars = await getAvailableCalendars();
      if (calendars.isEmpty) {
        return _generateDefaultSlots(duration, from, to, maxResults);
      }

      // Collect all events across calendars
      final allEvents = <Event>[];
      for (final calendar in calendars) {
        final result = await _plugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: from, endDate: to),
        );
        if (result.isSuccess && result.data != null) {
          allEvents.addAll(result.data!);
        }
      }

      // Find free slots
      final freeSlots = _findFreeSlotsFromEvents(
        allEvents,
        duration,
        from,
        to,
        maxResults,
      );

      // If no free slots found, suggest default times
      if (freeSlots.isEmpty) {
        return _generateDefaultSlots(duration, from, to, maxResults);
      }

      return freeSlots;
    } catch (e) {
      debugPrint('Error finding free slots: $e');
      return _generateDefaultSlots(duration, from, to, maxResults);
    }
  }

  /// Find free time slots based on existing events
  List<TimeSlot> _findFreeSlotsFromEvents(
    List<Event> events,
    Duration duration,
    DateTime from,
    DateTime to,
    int maxResults,
  ) {
    // Sort events by start time
    final sortedEvents = List<Event>.from(events);
    sortedEvents.sort((a, b) {
      final aStart = a.start ?? DateTime.now();
      final bStart = b.start ?? DateTime.now();
      return aStart.compareTo(bStart);
    });

    final freeSlots = <TimeSlot>[];
    var searchStart = from;

    // Only consider reasonable working hours (8 AM - 9 PM)
    DateTime adjustToWorkingHours(DateTime dt) {
      if (dt.hour < 8) {
        return DateTime(dt.year, dt.month, dt.day, 8);
      } else if (dt.hour >= 21) {
        // Move to next day
        return DateTime(dt.year, dt.month, dt.day + 1, 8);
      }
      return dt;
    }

    searchStart = adjustToWorkingHours(searchStart);

    for (final event in sortedEvents) {
      if (freeSlots.length >= maxResults) break;

      final eventStart = event.start ?? searchStart;
      final eventEnd = event.end ?? eventStart.add(const Duration(hours: 1));

      // Check if there's a gap before this event
      if (eventStart.isAfter(searchStart)) {
        // Check each potential slot in the gap
        var slotStart = searchStart;
        while (slotStart.add(duration).isBefore(eventStart) ||
            slotStart.add(duration).isAtSameMomentAs(eventStart)) {
          if (freeSlots.length >= maxResults) break;

          final slotEnd = slotStart.add(duration);

          // Ensure within working hours
          if (slotStart.hour >= 8 && slotEnd.hour < 21) {
            freeSlots.add(TimeSlot(
              start: slotStart,
              end: slotEnd,
              label: _formatTimeSlotLabel(slotStart, slotEnd),
            ));
          }

          // Move to next potential slot (round to 30 min increments)
          slotStart = slotStart.add(const Duration(minutes: 30));
          slotStart = adjustToWorkingHours(slotStart);
        }
      }

      // Move search start to after this event
      if (eventEnd.isAfter(searchStart)) {
        searchStart = eventEnd;
        searchStart = adjustToWorkingHours(searchStart);
      }
    }

    // Check for free time after the last event
    if (freeSlots.length < maxResults && searchStart.isBefore(to)) {
      var slotStart = searchStart;
      while (slotStart.add(duration).isBefore(to) ||
          slotStart.add(duration).isAtSameMomentAs(to)) {
        if (freeSlots.length >= maxResults) break;

        final slotEnd = slotStart.add(duration);

        // Ensure within working hours
        if (slotStart.hour >= 8 && slotEnd.hour < 21) {
          freeSlots.add(TimeSlot(
            start: slotStart,
            end: slotEnd,
            label: _formatTimeSlotLabel(slotStart, slotEnd),
          ));
        }

        slotStart = slotStart.add(const Duration(minutes: 30));
        slotStart = adjustToWorkingHours(slotStart);
      }
    }

    return freeSlots;
  }

  /// Generate default time slots when calendar access is unavailable
  List<TimeSlot> _generateDefaultSlots(
    Duration duration,
    DateTime from,
    DateTime to,
    int maxResults,
  ) {
    final slots = <TimeSlot>[];
    final now = DateTime.now();

    // Round to next half hour
    var slotStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute < 30 ? 30 : 0,
    );
    if (now.minute >= 30) {
      slotStart = slotStart.add(const Duration(hours: 1));
    }

    // Adjust if too early or too late
    if (slotStart.hour < 8) {
      slotStart = DateTime(slotStart.year, slotStart.month, slotStart.day, 8);
    } else if (slotStart.hour >= 20) {
      slotStart =
          DateTime(slotStart.year, slotStart.month, slotStart.day + 1, 9);
    }

    // Generate slots
    while (slots.length < maxResults && slotStart.isBefore(to)) {
      final slotEnd = slotStart.add(duration);

      if (slotEnd.hour <= 21 && slotStart.isAfter(now)) {
        slots.add(TimeSlot(
          start: slotStart,
          end: slotEnd,
          label: _formatTimeSlotLabel(slotStart, slotEnd),
        ));
      }

      // Move to next slot
      slotStart = slotStart.add(const Duration(hours: 2));

      // Skip to next day's morning if we're past evening
      if (slotStart.hour >= 20) {
        slotStart =
            DateTime(slotStart.year, slotStart.month, slotStart.day + 1, 9);
      }
    }

    return slots;
  }

  /// Format a time slot label for display
  String _formatTimeSlotLabel(DateTime start, DateTime end) {
    final now = DateTime.now();
    final startDay = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    String dayPrefix;
    if (startDay == today) {
      dayPrefix = 'Today';
    } else if (startDay == tomorrow) {
      dayPrefix = 'Tomorrow';
    } else {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      dayPrefix = weekdays[start.weekday - 1];
    }

    final startHour = start.hour;
    final startMinute = start.minute.toString().padLeft(2, '0');
    final endHour = end.hour;
    final endMinute = end.minute.toString().padLeft(2, '0');

    final startAmPm = startHour >= 12 ? 'PM' : 'AM';
    final endAmPm = endHour >= 12 ? 'PM' : 'AM';
    final displayStartHour = startHour > 12 ? startHour - 12 : startHour;
    final displayEndHour = endHour > 12 ? endHour - 12 : endHour;

    return '$dayPrefix $displayStartHour:$startMinute$startAmPm - $displayEndHour:$endMinute$endAmPm';
  }

  /// Find the next available hour slot starting from now
  Future<TimeSlot?> findNextAvailableHour() async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final endOfTomorrow =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 21);

    final slots = await findFreeSlots(
      const Duration(hours: 1),
      now,
      endOfTomorrow,
      maxResults: 1,
    );

    return slots.isNotEmpty ? slots.first : null;
  }

  /// Enable calendar integration (requests permission if needed)
  Future<bool> enableCalendar() async {
    final granted = await requestCalendarPermission();
    if (granted) {
      calendarEnabled = true;

      // Set default calendar if not already set
      if (defaultCalendarId == null) {
        final calendars = await getAvailableCalendars();
        if (calendars.isNotEmpty) {
          // Prefer primary calendar if available
          final primary = calendars.firstWhere(
            (c) => c.isDefault == true,
            orElse: () => calendars.first,
          );
          defaultCalendarId = primary.id;
        }
      }
    }
    return granted;
  }

  /// Disable calendar integration
  void disableCalendar() {
    calendarEnabled = false;
  }
}

/// Represents a suggested time slot for scheduling
class TimeSlot {
  final DateTime start;
  final DateTime end;
  final String label;

  const TimeSlot({
    required this.start,
    required this.end,
    required this.label,
  });

  Duration get duration => end.difference(start);

  @override
  String toString() => label;
}
