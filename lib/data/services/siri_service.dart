import 'package:flutter/foundation.dart';
import '../models/routine.dart';

/// Service for managing Siri Shortcuts integration
/// 
/// Allows users to trigger app actions via Siri (iOS only).
/// On Android, all methods are no-ops.
class SiriService {
  static final SiriService _instance = SiriService._internal();
  factory SiriService() => _instance;
  SiriService._internal();

  bool _initialized = false;

  /// Callback functions for handling intent results
  Function()? onStartNewTask;
  Function()? onContinueTask;
  Function()? onShowProgress;
  Function(String routineName)? onStartRoutine;

  /// Initialize Siri Shortcuts integration
  Future<void> initialize() async {
    if (_initialized) return;

    // Siri Shortcuts only available on iOS
    if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)) {
      debugPrint('SiriService: Skipping - not iOS');
      _initialized = true;
      return;
    }

    try {
      // Siri Shortcuts disabled for v1 — re-enable when flutter_app_intents is stable
      _initialized = true;
      debugPrint('SiriService: Initialized successfully');
    } catch (e) {
      debugPrint('SiriService: Failed to initialize: $e');
      _initialized = true; // Don't block app startup
    }
  }

  /// Donate an activity for Siri suggestions (iOS only)
  Future<void> donateActivity(String type, {Map<String, dynamic>? metadata}) async {
    if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) || !_initialized) return;
    debugPrint('SiriService: Would donate activity: $type');
  }

  /// Donate task decomposition started
  Future<void> donateDecomposeStarted(String taskName) async {
    await donateActivity('decompose_started', metadata: {'task': taskName});
  }

  /// Donate task decomposition activity
  Future<void> donateTaskDecomposition(String taskName) async {
    await donateActivity('decompose_task', metadata: {'task': taskName});
  }

  /// Donate task completed
  Future<void> donateTaskCompleted(String taskName) async {
    await donateActivity('task_completed', metadata: {'task': taskName});
  }

  /// Donate continue task
  Future<void> donateContinueTask() async {
    await donateActivity('continue_task');
  }

  /// Donate stats viewed
  Future<void> donateStatsViewed() async {
    await donateActivity('stats_viewed');
  }

  /// Donate routine used
  Future<void> donateRoutineUsed(Routine routine) async {
    await donateActivity('routine_used', metadata: {'routine': routine.name});
  }

  /// Donate routine activity (alias)
  Future<void> donateRoutineUse(Routine routine) async {
    await donateRoutineUsed(routine);
  }
}
