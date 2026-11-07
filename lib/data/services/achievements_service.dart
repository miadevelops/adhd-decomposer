import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'stats_service.dart';

/// Achievement definition
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int targetValue;
  final String progressUnit;
  final int Function(StatsService stats) currentValue;
  final bool Function(StatsService stats, AchievementsService achievements)
      checkUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.targetValue,
    required this.progressUnit,
    required this.currentValue,
    required this.checkUnlocked,
  });
}

/// Service for tracking and unlocking achievements
class AchievementsService extends ChangeNotifier {
  static const String _boxName = 'achievements';
  static const String keyUnlockedAchievements = 'unlockedAchievements';
  static const String keyNewlyUnlocked = 'newlyUnlocked';

  Box<dynamic>? _box;
  StatsService? _statsService;

  // List of newly unlocked achievements to celebrate
  final List<Achievement> _newlyUnlockedQueue = [];

  Future<void> initialize(StatsService statsService) async {
    _box = await Hive.openBox(_boxName);
    _statsService = statsService;
  }

  Box<dynamic> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
          'AchievementsService not initialized. Call initialize() first.');
    }
    return _box!;
  }

  StatsService get _stats {
    if (_statsService == null) {
      throw StateError(
          'AchievementsService not initialized. Call initialize() first.');
    }
    return _statsService!;
  }

  /// All available achievements
  static final List<Achievement> allAchievements = List.unmodifiable([
        Achievement(
          id: 'first_step',
          title: 'First Step',
          description: 'Complete your first task',
          icon: '🎯',
          targetValue: 1,
          progressUnit: 'task',
          currentValue: (stats) => stats.totalTasksCompleted,
          checkUnlocked: (stats, _) => stats.totalTasksCompleted >= 1,
        ),
        Achievement(
          id: 'getting_started',
          title: 'Getting Started',
          description: 'Complete 5 tasks',
          icon: '🚀',
          targetValue: 5,
          progressUnit: 'tasks',
          currentValue: (stats) => stats.totalTasksCompleted,
          checkUnlocked: (stats, _) => stats.totalTasksCompleted >= 5,
        ),
        Achievement(
          id: 'task_master',
          title: 'Task Master',
          description: 'Complete 25 tasks',
          icon: '⭐',
          targetValue: 25,
          progressUnit: 'tasks',
          currentValue: (stats) => stats.totalTasksCompleted,
          checkUnlocked: (stats, _) => stats.totalTasksCompleted >= 25,
        ),
        Achievement(
          id: 'on_a_roll',
          title: 'On a Roll',
          description: '3-day completion streak',
          icon: '🔥',
          targetValue: 3,
          progressUnit: 'days',
          currentValue: (stats) => stats.currentStreak > stats.longestStreak
              ? stats.currentStreak
              : stats.longestStreak,
          checkUnlocked: (stats, _) =>
              stats.currentStreak >= 3 || stats.longestStreak >= 3,
        ),
        Achievement(
          id: 'unstoppable',
          title: 'Unstoppable',
          description: '7-day completion streak',
          icon: '💪',
          targetValue: 7,
          progressUnit: 'days',
          currentValue: (stats) => stats.currentStreak > stats.longestStreak
              ? stats.currentStreak
              : stats.longestStreak,
          checkUnlocked: (stats, _) =>
              stats.currentStreak >= 7 || stats.longestStreak >= 7,
        ),
        Achievement(
          id: 'century',
          title: 'Century',
          description: 'Complete 100 steps total',
          icon: '💯',
          targetValue: 100,
          progressUnit: 'steps',
          currentValue: (stats) => stats.totalStepsCompleted,
          checkUnlocked: (stats, _) => stats.totalStepsCompleted >= 100,
        ),
        Achievement(
          id: 'time_master',
          title: 'Time Master',
          description: 'Use the timer 10 times',
          icon: '⏱️',
          targetValue: 10,
          progressUnit: 'sessions',
          currentValue: (stats) => stats.timerUsageCount,
          checkUnlocked: (stats, _) => stats.timerUsageCount >= 10,
        ),
        Achievement(
          id: 'template_pro',
          title: 'Template Pro',
          description: 'Use 5 different templates',
          icon: '📋',
          targetValue: 5,
          progressUnit: 'templates',
          currentValue: (stats) => stats.templatesUsed.length,
          checkUnlocked: (stats, _) => stats.templatesUsed.length >= 5,
        ),
      ]);

  // Decoded unlocked IDs, reused while the stored string is unchanged.
  Object? _unlockedRaw;
  Set<String> _unlockedCache = const {};

  /// Get set of unlocked achievement IDs
  Set<String> get unlockedAchievementIds {
    final stored = _safeBox.get(keyUnlockedAchievements);
    if (stored == null) return {};
    if (stored == _unlockedRaw) return Set.of(_unlockedCache);
    try {
      _unlockedCache = Set<String>.from(jsonDecode(stored) as List);
      _unlockedRaw = stored;
      return Set.of(_unlockedCache);
    } catch (e) {
      debugPrint('AchievementsService: could not read unlocked achievements: $e');
      // Keep a copy so the next write doesn't destroy it
      const backupKey = '${keyUnlockedAchievements}_corrupt';
      if (_safeBox.get(backupKey) == null) _safeBox.put(backupKey, stored);
      return {};
    }
  }

  set unlockedAchievementIds(Set<String> value) {
    _safeBox.put(keyUnlockedAchievements, jsonEncode(value.toList()));
  }

  /// Check if specific achievement is unlocked
  bool isUnlocked(String achievementId) {
    return unlockedAchievementIds.contains(achievementId);
  }

  /// Get all achievements with their unlock status
  List<(Achievement, bool)> get achievementsWithStatus {
    final unlocked = unlockedAchievementIds;
    return allAchievements.map((a) => (a, unlocked.contains(a.id))).toList();
  }

  /// Achievements ordered for display: unlocked milestones first, then locked.
  List<(Achievement, bool)> get orderedAchievementsWithStatus {
    final statuses = achievementsWithStatus;
    return [
      ...statuses.where((entry) => entry.$2),
      ...statuses.where((entry) => !entry.$2),
    ];
  }

  /// The locked achievement closest to completion.
  Achievement? get nextAchievement {
    final locked = achievementsWithStatus
        .where((entry) => !entry.$2)
        .map((entry) => entry.$1)
        .toList();
    if (locked.isEmpty) return null;

    var next = locked.first;
    for (final achievement in locked.skip(1)) {
      if (progressFor(achievement) > progressFor(next)) {
        next = achievement;
      }
    }
    return next;
  }

  double progressFor(Achievement achievement) {
    if (achievement.targetValue <= 0) return 1;
    return (achievement.currentValue(_stats) / achievement.targetValue)
        .clamp(0.0, 1.0);
  }

  String progressLabelFor(Achievement achievement) {
    final current =
        achievement.currentValue(_stats).clamp(0, achievement.targetValue);
    return '$current of ${achievement.targetValue} ${achievement.progressUnit}';
  }

  /// Get count of unlocked achievements
  int get unlockedCount => unlockedAchievementIds.length;

  /// Get total achievement count
  int get totalCount => allAchievements.length;

  /// Get queue of newly unlocked achievements to celebrate
  List<Achievement> get newlyUnlockedQueue => _newlyUnlockedQueue;

  /// Pop the next achievement to celebrate
  Achievement? popNewlyUnlocked() {
    if (_newlyUnlockedQueue.isEmpty) return null;
    final achievement = _newlyUnlockedQueue.removeAt(0);
    notifyListeners();
    return achievement;
  }

  /// Clear the newly unlocked queue
  void clearNewlyUnlocked() {
    _newlyUnlockedQueue.clear();
    notifyListeners();
  }

  /// Check and unlock any newly earned achievements
  /// Returns list of newly unlocked achievements
  List<Achievement> checkAndUnlockAchievements() {
    final currentlyUnlocked = unlockedAchievementIds;
    final newlyUnlocked = <Achievement>[];

    for (final achievement in allAchievements) {
      if (!currentlyUnlocked.contains(achievement.id)) {
        if (achievement.checkUnlocked(_stats, this)) {
          currentlyUnlocked.add(achievement.id);
          newlyUnlocked.add(achievement);
        }
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      unlockedAchievementIds = currentlyUnlocked;
      _newlyUnlockedQueue.addAll(newlyUnlocked);
      notifyListeners();
    }

    return newlyUnlocked;
  }
}
