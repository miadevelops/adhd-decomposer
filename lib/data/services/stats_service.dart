import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Service for tracking user statistics
class StatsService {
  static const String _boxName = 'stats';
  
  // Keys
  static const String keyTotalTasksCompleted = 'totalTasksCompleted';
  static const String keyTotalStepsCompleted = 'totalStepsCompleted';
  static const String keyTotalMinutesSpent = 'totalMinutesSpent';
  static const String keyCurrentStreak = 'currentStreak';
  static const String keyLongestStreak = 'longestStreak';
  static const String keyLastCompletionDate = 'lastCompletionDate';
  static const String keyDailyCompletions = 'dailyCompletions';
  static const String keyTimerUsageCount = 'timerUsageCount';
  static const String keyTemplatesUsed = 'templatesUsed';
  static const String keyTotalShares = 'totalShares';
  static const String keyTotalPomodoros = 'totalPomodoros';
  static const String keyTotalBodyDoubleMinutes = 'totalBodyDoubleMinutes';
  
  Box<dynamic>? _box;
  
  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
  }
  
  Box<dynamic> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('StatsService not initialized. Call initialize() first.');
    }
    return _box!;
  }
  
  // Total tasks completed
  int get totalTasksCompleted => _safeBox.get(keyTotalTasksCompleted, defaultValue: 0);
  set totalTasksCompleted(int value) => _safeBox.put(keyTotalTasksCompleted, value);
  
  // Total steps completed
  int get totalStepsCompleted => _safeBox.get(keyTotalStepsCompleted, defaultValue: 0);
  set totalStepsCompleted(int value) => _safeBox.put(keyTotalStepsCompleted, value);
  
  // Total minutes spent (from timer usage)
  int get totalMinutesSpent => _safeBox.get(keyTotalMinutesSpent, defaultValue: 0);
  set totalMinutesSpent(int value) => _safeBox.put(keyTotalMinutesSpent, value);
  
  // Current streak
  int get currentStreak => _safeBox.get(keyCurrentStreak, defaultValue: 0);
  set currentStreak(int value) => _safeBox.put(keyCurrentStreak, value);
  
  // Longest streak
  int get longestStreak => _safeBox.get(keyLongestStreak, defaultValue: 0);
  set longestStreak(int value) => _safeBox.put(keyLongestStreak, value);
  
  // Last completion date (ISO string)
  String? get lastCompletionDate => _safeBox.get(keyLastCompletionDate);
  set lastCompletionDate(String? value) => _safeBox.put(keyLastCompletionDate, value);
  
  // Timer usage count
  int get timerUsageCount => _safeBox.get(keyTimerUsageCount, defaultValue: 0);
  set timerUsageCount(int value) => _safeBox.put(keyTimerUsageCount, value);
  
  // Total shares
  int get totalShares => _safeBox.get(keyTotalShares, defaultValue: 0);
  set totalShares(int value) => _safeBox.put(keyTotalShares, value);
  
  // Total pomodoros completed (in Body Double mode)
  int get totalPomodoros => _safeBox.get(keyTotalPomodoros, defaultValue: 0);
  set totalPomodoros(int value) => _safeBox.put(keyTotalPomodoros, value);
  
  // Total minutes spent in Body Double mode
  int get totalBodyDoubleMinutes => _safeBox.get(keyTotalBodyDoubleMinutes, defaultValue: 0);
  set totalBodyDoubleMinutes(int value) => _safeBox.put(keyTotalBodyDoubleMinutes, value);
  
  // Templates used (stored as JSON list)
  Set<String> get templatesUsed {
    final stored = _safeBox.get(keyTemplatesUsed);
    if (stored == null) return {};
    try {
      return Set<String>.from(jsonDecode(stored) as List);
    } catch (_) {
      return {};
    }
  }
  
  set templatesUsed(Set<String> value) {
    _safeBox.put(keyTemplatesUsed, jsonEncode(value.toList()));
  }
  
  // Daily completions (stored as JSON map: date -> count)
  Map<String, int> get dailyCompletions {
    final stored = _safeBox.get(keyDailyCompletions);
    if (stored == null) return {};
    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }
  
  set dailyCompletions(Map<String, int> value) {
    _safeBox.put(keyDailyCompletions, jsonEncode(value));
  }
  
  /// Get completions for last 7 days (including today)
  List<DailyStats> getLast7DaysStats() {
    final now = DateTime.now();
    final completions = dailyCompletions;
    final result = <DailyStats>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dateKey = _dateToKey(date);
      result.add(DailyStats(
        date: date,
        tasksCompleted: completions[dateKey] ?? 0,
      ));
    }
    
    return result;
  }
  
  /// Record task completion
  void recordTaskCompletion() {
    final now = DateTime.now();
    final today = _dateToKey(now);
    
    // Increment totals
    totalTasksCompleted = totalTasksCompleted + 1;
    
    // Update daily completions
    final daily = dailyCompletions;
    daily[today] = (daily[today] ?? 0) + 1;
    
    // Clean up old data (keep only last 30 days)
    _cleanupOldDailyData(daily, now);
    dailyCompletions = daily;
    
    // Update streak
    _updateStreak(now);
  }
  
  /// Record step completion
  void recordStepCompletion() {
    totalStepsCompleted = totalStepsCompleted + 1;
  }
  
  /// Record timer usage
  void recordTimerUsage(int minutes) {
    timerUsageCount = timerUsageCount + 1;
    totalMinutesSpent = totalMinutesSpent + minutes;
  }
  
  /// Record template usage
  void recordTemplateUsed(String templateId) {
    final templates = templatesUsed;
    templates.add(templateId);
    templatesUsed = templates;
  }
  
  /// Record a share action
  void recordShare() {
    totalShares = totalShares + 1;
  }
  
  /// Record a completed pomodoro session
  void recordPomodoroCompleted() {
    totalPomodoros = totalPomodoros + 1;
  }
  
  /// Record time spent in Body Double mode
  void recordBodyDoubleMinutes(int minutes) {
    totalBodyDoubleMinutes = totalBodyDoubleMinutes + minutes;
  }
  
  void _updateStreak(DateTime now) {
    final today = _dateToKey(now);
    final yesterday = _dateToKey(now.subtract(const Duration(days: 1)));
    final lastDate = lastCompletionDate;
    
    if (lastDate == null) {
      // First completion ever
      currentStreak = 1;
    } else if (lastDate == today) {
      // Already completed today, streak stays the same
    } else if (lastDate == yesterday) {
      // Consecutive day - extend streak
      currentStreak = currentStreak + 1;
    } else {
      // Streak broken - start new streak
      currentStreak = 1;
    }
    
    // Update longest streak if needed
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }
    
    lastCompletionDate = today;
  }
  
  void _cleanupOldDailyData(Map<String, int> daily, DateTime now) {
    final cutoff = now.subtract(const Duration(days: 30));
    daily.removeWhere((dateKey, _) {
      final date = _keyToDate(dateKey);
      return date != null && date.isBefore(cutoff);
    });
  }
  
  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  DateTime? _keyToDate(String key) {
    try {
      return DateTime.parse(key);
    } catch (_) {
      return null;
    }
  }
}

/// Stats for a single day
class DailyStats {
  final DateTime date;
  final int tasksCompleted;
  
  DailyStats({required this.date, required this.tasksCompleted});
  
  String get dayName {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}
