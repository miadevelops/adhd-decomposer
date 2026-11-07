/// Screenshot-specific mock data and state builders for App Store screenshots.
/// This file provides pre-populated data that creates visually appealing screenshots.
library;

import '../data/models/task.dart';
import '../data/services/stats_service.dart';
import '../data/services/achievements_service.dart';

/// Mock data for screenshot scenarios
class ScreenshotData {
  ScreenshotData._();

  // ========== Tasks for Screenshots ==========

  /// A task in progress for the "Execute Screen" screenshot
  static Task get inProgressTask => Task(
    id: 'screenshot_task_1',
    title: 'Clean the kitchen',
    steps: [
      TaskStep(
        id: 'step_1',
        action: 'Clear the countertops',
        estimatedMinutes: 3,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      TaskStep(
        id: 'step_2',
        action: 'Load the dishwasher',
        estimatedMinutes: 5,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      TaskStep(
        id: 'step_3',
        action: 'Wipe down the stovetop',
        estimatedMinutes: 4,
        isCompleted: false,
      ),
      TaskStep(
        id: 'step_4',
        action: 'Clean the sink',
        estimatedMinutes: 3,
        isCompleted: false,
      ),
      TaskStep(
        id: 'step_5',
        action: 'Take out the trash',
        estimatedMinutes: 2,
        isCompleted: false,
      ),
    ],
    totalEstimatedMinutes: 17,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
  );

  /// A completed task for the "Celebration" screenshot
  static Task get completedTask => Task(
    id: 'screenshot_task_2',
    title: 'Organize my desk',
    steps: [
      TaskStep(
        id: 'step_1',
        action: 'Remove everything from desk',
        estimatedMinutes: 2,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
      TaskStep(
        id: 'step_2',
        action: 'Wipe down the surface',
        estimatedMinutes: 3,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(minutes: 17)),
      ),
      TaskStep(
        id: 'step_3',
        action: 'Sort papers into piles',
        estimatedMinutes: 5,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
      TaskStep(
        id: 'step_4',
        action: 'File or discard papers',
        estimatedMinutes: 5,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(minutes: 7)),
      ),
      TaskStep(
        id: 'step_5',
        action: 'Arrange items neatly',
        estimatedMinutes: 3,
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
      TaskStep(
        id: 'step_6',
        action: 'Add something nice (plant/photo)',
        estimatedMinutes: 2,
        isCompleted: true,
        completedAt: DateTime.now(),
      ),
    ],
    totalEstimatedMinutes: 20,
    createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    completedAt: DateTime.now(),
  );

  /// Task being decomposed for the "Decompose Screen" screenshot
  static const String decomposingTaskTitle = 'Prepare presentation for Monday';

  // ========== Stats for Screenshots ==========

  /// Stats data showing an impressive but believable streak
  static Map<String, dynamic> get screenshotStats => {
    'currentStreak': 7,
    'longestStreak': 14,
    'totalTasksCompleted': 47,
    'totalStepsCompleted': 234,
    'totalMinutesWorked': 892,
    'weeklyData': [
      {'date': _daysAgo(6), 'tasks': 3},
      {'date': _daysAgo(5), 'tasks': 2},
      {'date': _daysAgo(4), 'tasks': 4},
      {'date': _daysAgo(3), 'tasks': 2},
      {'date': _daysAgo(2), 'tasks': 5},
      {'date': _daysAgo(1), 'tasks': 3},
      {'date': _daysAgo(0), 'tasks': 4},
    ],
  };

  static DateTime _daysAgo(int days) => 
    DateTime.now().subtract(Duration(days: days));

  // ========== Achievements for Screenshots ==========

  /// Achievements that should appear unlocked in screenshots
  static List<String> get unlockedAchievementIds => [
    'first_step',       // Complete your first step
    'first_task',       // Complete your first task
    'streak_3',         // 3-day streak
    'streak_7',         // 7-day streak (current)
    'tasks_10',         // Complete 10 tasks
    'steps_100',        // Complete 100 steps
    'early_bird',       // Complete a task before 9 AM
    'night_owl',        // Complete a task after 10 PM
    'template_master',  // Use 5 different templates
  ];

  // ========== UI State Helpers ==========

  /// Timer display for execute screen (shows active timer)
  static const int timerSecondsRemaining = 4 * 60 + 32; // 4:32

  /// Encouragement message for celebration screen
  static const String celebrationMessage = 'You crushed it! 🎉';

  /// User name for onboarding personalization
  static const String userName = 'Alex';
}

/// Extension to help create mock stats state
extension StatsServiceScreenshotExtension on StatsService {
  /// Populate stats with screenshot-friendly data
  Future<void> populateForScreenshot() async {
    totalTasksCompleted = 47;
    totalStepsCompleted = 234;
    totalMinutesSpent = 892;
    currentStreak = 7;
    longestStreak = 14;
    
    // Set up weekly data
    final now = DateTime.now();
    final daily = <String, int>{};
    final weeklyData = [3, 2, 4, 2, 5, 3, 4];
    
    for (var i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      daily[dateKey] = weeklyData[i];
    }
    dailyCompletions = daily;
    
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    lastCompletionDate = todayKey;
  }
}

/// Extension to help create mock achievements state
extension AchievementsServiceScreenshotExtension on AchievementsService {
  /// Unlock specific achievements for screenshots
  Future<void> populateForScreenshot() async {
    // Achievements auto-unlock based on stats
    // Implementation depends on AchievementsService internals
  }
}
