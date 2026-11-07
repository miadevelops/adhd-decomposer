import 'package:flutter/material.dart';
import 'task.dart';

/// Recurrence types for routines
enum RecurrenceType {
  daily,     // Every day
  weekdays,  // Monday-Friday
  weekly,    // Specific days of the week
  monthly,   // Specific day of the month
}

/// Model for recurring routines
class Routine {
  final String id;
  String name;
  List<TaskStep> steps;
  RecurrenceType recurrence;
  TimeOfDay preferredTime;
  List<int> daysOfWeek; // 1-7 (Monday-Sunday) for weekly recurrence
  int? dayOfMonth; // 1-31 for monthly recurrence
  DateTime? lastCompleted;
  int _completionStreak;
  DateTime createdAt;
  int totalEstimatedMinutes;

  Routine({
    required this.id,
    required this.name,
    required this.steps,
    required this.recurrence,
    required this.preferredTime,
    this.daysOfWeek = const [],
    this.dayOfMonth,
    this.lastCompleted,
    int completionStreak = 0,
    DateTime? createdAt,
    int? totalEstimatedMinutes,
  }) : _completionStreak = completionStreak,
       createdAt = createdAt ?? DateTime.now(),
       totalEstimatedMinutes = totalEstimatedMinutes ?? 
           steps.fold(0, (sum, step) => sum + step.estimatedMinutes);

  /// Current streak. Reads as 0 once a scheduled occurrence has been missed,
  /// even before the next completion resets the stored value.
  int get completionStreak =>
      _streakIntact(_dateOnly(DateTime.now())) ? _completionStreak : 0;

  /// Check if this routine is due today
  bool isDueToday() {
    if (isCompletedToday()) return false;
    return isScheduledOn(DateTime.now());
  }

  /// Whether the recurrence rule includes the given calendar day.
  bool isScheduledOn(DateTime day) {
    switch (recurrence) {
      case RecurrenceType.daily:
        return true;
        
      case RecurrenceType.weekdays:
        // Monday = 1, Sunday = 7
        return day.weekday >= 1 && day.weekday <= 5;
        
      case RecurrenceType.weekly:
        return daysOfWeek.contains(day.weekday);
        
      case RecurrenceType.monthly:
        if (dayOfMonth == null) return false;
        // Handle months with fewer days
        final lastDayOfMonth = DateTime(day.year, day.month + 1, 0).day;
        final effectiveDay = dayOfMonth! > lastDayOfMonth 
            ? lastDayOfMonth 
            : dayOfMonth!;
        return day.day == effectiveDay;
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Most recent scheduled day strictly before [today], or null if none in
  /// the last ~2 months (e.g. a weekly routine with no days selected).
  DateTime? _previousScheduledDay(DateTime today) {
    for (var i = 1; i <= 62; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      if (isScheduledOn(day)) return day;
    }
    return null;
  }

  /// The streak survives as long as no scheduled day between the last
  /// completion and today was missed. Today itself is still open.
  bool _streakIntact(DateTime today) {
    if (lastCompleted == null) return false;
    final lastDate = _dateOnly(lastCompleted!);
    if (!lastDate.isBefore(today)) return true;
    final previous = _previousScheduledDay(today);
    return previous == null || !lastDate.isBefore(previous);
  }

  /// Check if this routine is completed today
  bool isCompletedToday() {
    if (lastCompleted == null) return false;
    final now = DateTime.now();
    return lastCompleted!.year == now.year &&
           lastCompleted!.month == now.month &&
           lastCompleted!.day == now.day;
  }

  /// Mark routine as complete and update streak. Returns false (and changes
  /// nothing) if it was already completed today.
  bool markComplete() {
    if (isCompletedToday()) return false;
    final now = DateTime.now();
    _completionStreak = _streakIntact(_dateOnly(now)) ? _completionStreak + 1 : 1;
    lastCompleted = now;
    return true;
  }

  /// Get human-readable recurrence description
  String get recurrenceDescription {
    switch (recurrence) {
      case RecurrenceType.daily:
        return 'Every day';
      case RecurrenceType.weekdays:
        return 'Weekdays';
      case RecurrenceType.weekly:
        if (daysOfWeek.isEmpty) return 'Weekly';
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = daysOfWeek.map((d) => dayNames[d - 1]).join(', ');
        return days;
      case RecurrenceType.monthly:
        if (dayOfMonth == null) return 'Monthly';
        final suffix = _getOrdinalSuffix(dayOfMonth!);
        return '$dayOfMonth$suffix of month';
    }
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  /// Create a Task instance from this routine for execution
  Task toTask() {
    // Create fresh copies of steps (not completed)
    final freshSteps = steps.map((s) => TaskStep(
      id: s.id,
      action: s.action,
      estimatedMinutes: s.estimatedMinutes,
      isCompleted: false,
      isSkipped: false,
      subSteps: s.subSteps?.map((sub) => TaskStep(
        id: sub.id,
        action: sub.action,
        estimatedMinutes: sub.estimatedMinutes,
      )).toList(),
    )).toList();

    return Task(
      id: 'routine_${id}_${DateTime.now().millisecondsSinceEpoch}',
      title: name,
      steps: freshSteps,
      totalEstimatedMinutes: totalEstimatedMinutes,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'steps': steps.map((s) => s.toJson()).toList(),
    'recurrence': recurrence.name,
    'preferredTimeHour': preferredTime.hour,
    'preferredTimeMinute': preferredTime.minute,
    'daysOfWeek': daysOfWeek,
    'dayOfMonth': dayOfMonth,
    'lastCompleted': lastCompleted?.toIso8601String(),
    'completionStreak': completionStreak,
    'createdAt': createdAt.toIso8601String(),
    'totalEstimatedMinutes': totalEstimatedMinutes,
  };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'],
    name: json['name'],
    steps: (json['steps'] as List)
        .map((s) => TaskStep.fromJson(s as Map<String, dynamic>))
        .toList(),
    recurrence: RecurrenceType.values.firstWhere(
      (e) => e.name == json['recurrence'],
      orElse: () => RecurrenceType.daily,
    ),
    preferredTime: TimeOfDay(
      hour: json['preferredTimeHour'] ?? 9,
      minute: json['preferredTimeMinute'] ?? 0,
    ),
    daysOfWeek: (json['daysOfWeek'] as List?)?.cast<int>() ?? [],
    dayOfMonth: json['dayOfMonth'],
    lastCompleted: json['lastCompleted'] != null 
        ? DateTime.parse(json['lastCompleted']) 
        : null,
    completionStreak: json['completionStreak'] ?? 0,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : null,
    totalEstimatedMinutes: json['totalEstimatedMinutes'],
  );

  /// Copy routine with modifications
  Routine copyWith({
    String? id,
    String? name,
    List<TaskStep>? steps,
    RecurrenceType? recurrence,
    TimeOfDay? preferredTime,
    List<int>? daysOfWeek,
    int? dayOfMonth,
    DateTime? lastCompleted,
    int? completionStreak,
    int? totalEstimatedMinutes,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      recurrence: recurrence ?? this.recurrence,
      preferredTime: preferredTime ?? this.preferredTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      completionStreak: completionStreak ?? this.completionStreak,
      createdAt: createdAt,
      totalEstimatedMinutes: totalEstimatedMinutes ?? this.totalEstimatedMinutes,
    );
  }
}
