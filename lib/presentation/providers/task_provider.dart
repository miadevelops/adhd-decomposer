import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/task.dart';
import '../../data/models/coach.dart';
import '../../data/models/routine.dart';
import '../../data/coaches.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/json_list_storage.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/stats_service.dart';
import '../../data/services/achievements_service.dart';
import '../../data/services/widget_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/purchase_service.dart';
import '../../data/services/xp_service.dart';
import '../../data/services/siri_service.dart';

// Re-export DecompositionStyle for UI access
export '../../data/services/ai_service.dart' show DecompositionStyle;
// Re-export DefaultAmbientSound for UI access
export '../../data/services/settings_service.dart' show DefaultAmbientSound;
// Re-export Coach types for UI access
export '../../data/models/coach.dart' show Coach, CoachType;
export '../../data/coaches.dart' show Coaches;

class TaskProvider extends ChangeNotifier {
  final AIService _aiService;
  final SettingsService? _settings;
  final StatsService? _stats;
  final AchievementsService? _achievements;
  final NotificationService? _notifications;
  PurchaseService? _purchases;
  final XPService? _xpService;
  List<Task> _tasks = [];
  Task? _activeTask;
  bool _isLoading = false;
  String? _error;
  bool _usedTimerThisTask = false;
  bool _isFromTemplate = false;

  TaskProvider({
    AIService? aiService,
    SettingsService? settings,
    StatsService? stats,
    AchievementsService? achievements,
    NotificationService? notifications,
    PurchaseService? purchases,
    XPService? xpService,
  })  : _aiService = aiService ?? AIService(),
        _settings = settings,
        _stats = stats,
        _achievements = achievements,
        _notifications = notifications,
        _purchases = purchases,
        _xpService = xpService {
    _attachPurchases(_purchases);
    }

  bool _backendPremiumLinked = false;

  void _attachPurchases(PurchaseService? purchases) {
    if (purchases == null) return;
    purchases.addListener(_onPurchasesChanged);
    _settings?.syncPremiumStatus(purchases.isPremium);
    if (purchases.isPremium) _linkPremiumWithBackend();
  }

  void _onPurchasesChanged() {
    final purchases = _purchases;
    if (purchases == null) return;
    _settings?.syncPremiumStatus(purchases.isPremium);
    if (purchases.isPremium) {
      _linkPremiumWithBackend();
    } else {
      _backendPremiumLinked = false;
    }
    notifyListeners();
  }

  /// Tell the backend which RevenueCat customer this device belongs to so it
  /// can verify premium server-side. Returns the backend's premium verdict.
  Future<bool> _linkPremiumWithBackend({bool force = false}) async {
    if (_backendPremiumLinked && !force) return true;
    final appUserId = await _purchases?.getAppUserId();
    if (appUserId == null || appUserId.isEmpty) return false;
    final verified =
        await _aiService.verifySubscription(revenueCatUserId: appUserId);
    _backendPremiumLinked = verified;
    return verified;
  }

  /// Runs an AI call; if the backend says the free allowance is used up but
  /// RevenueCat says this user is premium, re-link and retry once.
  Future<T> _withPremiumRetry<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on RateLimitException catch (e) {
      if (e.isFreeLimitReached &&
          isPremium &&
          await _linkPremiumWithBackend(force: true)) {
        return call();
      }
      rethrow;
    }
  }

  /// Count an AI call against the free allowance, preferring the server's count.
  /// Offline-template results are never counted.
  void _recordAiUsage() {
    if (_aiService.lastSource != AIResultSource.backend) return;
    if (isPremium || hasCustomApiKey) return;
    final usage = _aiService.lastUsage;
    if (usage != null && !usage.isUnlimited) {
      _settings?.syncDecompositionCount(usage.used);
    } else {
      _settings?.incrementDecompositionCount();
    }
  }

  @override
  void dispose() {
    _purchases?.removeListener(_onPurchasesChanged);
    super.dispose();
  }

  List<Task> get tasks => _tasks;
  List<Task> get activeTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted).toList();
  Task? get activeTask => _activeTask;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Settings getters for UI
  bool get soundEnabled => _settings?.soundEnabled ?? true;
  bool get hapticEnabled => _settings?.hapticEnabled ?? true;
  bool get confettiEnabled => _settings?.confettiEnabled ?? true;
  bool get celebrationSoundEnabled =>
      _settings?.celebrationSoundEnabled ?? true;
  String get selectedCelebrationSound => _xpService?.selectedSound ?? 'default';
  bool get canDecompose =>
      isPremium ||
      hasCustomApiKey ||
      !(_settings?.hasReachedFreeLimit ?? false);
  /// Remaining free breakdowns (task and "I'm stuck" share one lifetime pool).
  /// -1 means unlimited. The backend is the source of truth for the count.
  int get remainingFreeDecompositions =>
      _settings?.remainingFreeDecompositions ?? -1;

  /// Check if user has premium access (from PurchaseService or settings cache)
  bool get isPremium => _purchases?.isPremium ?? _settings?.isPremium ?? false;

  bool get hasCustomApiKey => _settings?.hasCustomApiKey ?? false;
  DecompositionStyle get decompositionStyle =>
      _settings?.decompositionStyle ?? DecompositionStyle.standard;
  // Accessibility settings getters
  bool get reduceAnimations => _settings?.reduceAnimations ?? false;
  bool get autoAdvanceEnabled => _settings?.autoAdvanceEnabled ?? true;
  // Body Double settings getters
  DefaultAmbientSound get defaultAmbientSound =>
      _settings?.defaultAmbientSound ?? DefaultAmbientSound.none;

  // AI Coach settings getters
  CoachType get selectedCoachType =>
      _settings?.selectedCoachType ?? CoachType.default_;
  Coach get selectedCoach => _settings?.selectedCoach ?? Coaches.default_;

  // User personalization
  String? get userName => _settings?.userName;

  // Notification settings getters for UI
  bool get notificationsEnabled =>
      _notifications?.notificationsEnabled ?? false;
  int get reminderHour => _notifications?.reminderHour ?? 9;
  int get reminderMinute => _notifications?.reminderMinute ?? 0;
  bool get gentleNudgeEnabled => _notifications?.gentleNudgeEnabled ?? true;

  // Settings setters
  void setSoundEnabled(bool value) {
    _settings?.soundEnabled = value;
    notifyListeners();
  }

  void setHapticEnabled(bool value) {
    _settings?.hapticEnabled = value;
    notifyListeners();
  }

  void setConfettiEnabled(bool value) {
    _settings?.confettiEnabled = value;
    notifyListeners();
  }

  void setCelebrationSoundEnabled(bool value) {
    _settings?.celebrationSoundEnabled = value;
    notifyListeners();
  }

  void setReduceAnimations(bool value) {
    _settings?.reduceAnimations = value;
    notifyListeners();
  }

  void setAutoAdvanceEnabled(bool value) {
    _settings?.autoAdvanceEnabled = value;
    notifyListeners();
  }

  void setDecompositionStyle(DecompositionStyle style) {
    _settings?.decompositionStyle = style;
    notifyListeners();
  }

  void setDefaultAmbientSound(DefaultAmbientSound sound) {
    _settings?.defaultAmbientSound = sound;
    notifyListeners();
  }

  void setSelectedCoach(CoachType coachType) {
    _settings?.selectedCoachType = coachType;
    notifyListeners();
  }

  void setUserName(String? name) {
    _settings?.userName = name;
    notifyListeners();
  }

  void setOpenAIApiKey(String? key) {
    _settings?.openAIApiKey = key;
    notifyListeners();
  }

  String? get openAIApiKey => _settings?.openAIApiKey;

  // Notification settings setters
  Future<bool> enableNotifications() async {
    final enabled = await _notifications?.enableNotifications() ?? false;
    notifyListeners();
    return enabled;
  }

  Future<void> disableNotifications() async {
    await _notifications?.disableNotifications();
    notifyListeners();
  }

  Future<void> setReminderTime(int hour, int minute) async {
    await _notifications?.setReminderTime(hour, minute);
    notifyListeners();
  }

  Future<void> setGentleNudgeEnabled(bool value) async {
    _notifications?.gentleNudgeEnabled = value;
    if (!value) {
      await _notifications?.clearUnfinishedTaskReminder();
    }
    notifyListeners();
  }

  Future<void> showTestNotification() async {
    await _notifications?.showTestNotification();
  }

  /// Set or update the PurchaseService reference
  /// This allows premium status updates to propagate
  void setPurchaseService(PurchaseService? purchases) {
    if (identical(purchases, _purchases)) {
      notifyListeners();
      return;
    }
    _purchases?.removeListener(_onPurchasesChanged);
    _purchases = purchases;
    _backendPremiumLinked = false;
    _attachPurchases(purchases);
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final box = await Hive.openBox<String>('tasks');
      _tasks = await JsonListStorage.load(box, 'tasksList', Task.fromJson);
      _tasksLoaded = true;
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      _tasks = [];
    }
    notifyListeners();
  }

  /// False until stored tasks are read successfully; saving is blocked until
  /// then so a failed load can't wipe the user's saved tasks.
  bool _tasksLoaded = false;

  Future<void> _saveTasks() async {
    if (!_tasksLoaded) {
      debugPrint('TaskProvider: skipping save because tasks failed to load');
      return;
    }
    try {
      final box = await Hive.openBox<String>('tasks');
      final encoded = JsonListStorage.encode(_tasks, (Task t) => t.toJson());
      await box.put('tasksList', encoded);
    } catch (e) {
      debugPrint('Error saving tasks: $e');
    }
  }

  Future<Task?> decomposeTask(String description) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use custom API key if available
      final apiKey = _settings?.openAIApiKey;
      final style =
          _settings?.decompositionStyle ?? DecompositionStyle.standard;
      final coach = _settings?.selectedCoach ?? Coaches.default_;
      final task = await _withPremiumRetry(() => _aiService.decomposeTask(
        description,
        apiKey: apiKey,
        style: style,
        coach: coach,
          ));
      _tasks.insert(0, task);
      await _saveTasks();

      _recordAiUsage();

      _isLoading = false;
      notifyListeners();
      return task;
    } on RateLimitException catch (e) {
      if (e.isFreeLimitReached) {
        _settings?.markFreeLimitReached();
      }
      _error = friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Task breakdown failed: $e');
      _error = friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// User-facing text for an AI failure (never raw exception text).
  static String friendlyError(Object e) {
    if (e is RateLimitException) {
      return e.isFreeLimitReached
          ? "You've used your free breakdowns."
          : 'Lots of requests right now. Give it a minute and try again.';
    }
    return "Couldn't break that down right now. Check your connection and try again.";
  }

  /// Steps of a plan that can still be edited (not done or skipped yet).
  bool canEditStep(Task task, int index) =>
      index >= task.currentStepIndex && index < task.steps.length;

  /// Rewords or re-times one upcoming step of a plan.
  void updateStep(Task task, int index,
      {String? action, int? estimatedMinutes}) {
    if (!canEditStep(task, index)) return;
    final step = task.steps[index];
    if (action != null && action.trim().isNotEmpty) {
      step.action = action.trim();
    }
    if (estimatedMinutes != null && estimatedMinutes > 0) {
      step.estimatedMinutes = estimatedMinutes;
    }
    _recalculateEstimate(task);
    _saveTasks();
    _updateWidget();
    notifyListeners();
  }

  /// Removes one upcoming step. A plan always keeps at least one step.
  void removeStep(Task task, int index) {
    if (!canEditStep(task, index) || task.steps.length <= 1) return;
    task.steps.removeAt(index);
    _recalculateEstimate(task);
    _saveTasks();
    _updateWidget();
    notifyListeners();
  }

  void _recalculateEstimate(Task task) {
    task.totalEstimatedMinutes =
        task.steps.fold<int>(0, (sum, s) => sum + s.estimatedMinutes);
  }

  void setActiveTask(Task? task) {
    _activeTask = task;
    _updateWidget();

    // Reset task-specific tracking flags
    _usedTimerThisTask = false;
    _isFromTemplate = false;

    // Schedule unfinished task reminder if task is set
    if (task != null && !task.isCompleted) {
      _notifications?.scheduleUnfinishedTaskReminder(task.id);
    } else {
      _notifications?.clearUnfinishedTaskReminder();
    }

    notifyListeners();
  }

  void completeCurrentStep() {
    if (_activeTask != null) {
      final wasCompleted = _activeTask!.isCompleted;
      _activeTask!.completeCurrentStep();

      // Record step completion
      _stats?.recordStepCompletion();

      // Award XP for step completion
      _xpService?.awardStepComplete();

      // Update notification activity (resets 2-hour timer)
      _notifications?.updateTaskActivity();

      if (!wasCompleted && _activeTask!.isCompleted) {
        _onTaskEnded(_activeTask!);
      }

      _saveTasks();
      _updateWidget();
      notifyListeners();
    }
  }

  void skipCurrentStep() {
    if (_activeTask != null) {
      final wasCompleted = _activeTask!.isCompleted;
      _activeTask!.skipCurrentStep();

      // Update notification activity (resets 2-hour timer)
      _notifications?.updateTaskActivity();

      if (!wasCompleted && _activeTask!.isCompleted) {
        _onTaskEnded(_activeTask!);
      }

      _saveTasks();
      _updateWidget();
      notifyListeners();
    }
  }

  /// Single path for a task reaching its end, whether the last step was
  /// completed or skipped. Only tasks with real progress earn rewards.
  void _onTaskEnded(Task task) {
    _notifications?.clearUnfinishedTaskReminder();

    if (task.endedWithoutProgress) {
      _usedTimerThisTask = false;
      _isFromTemplate = false;
      return;
    }

        _stats?.recordTaskCompletion();

        _xpService?.awardTaskComplete(
          usedTimer: _usedTimerThisTask,
          isFromTemplate: _isFromTemplate,
        );

        final currentStreak = _stats?.currentStreak ?? 0;
        if (currentStreak > 0) {
          _xpService?.awardStreakBonus(currentStreak);
        }

        _usedTimerThisTask = false;
        _isFromTemplate = false;

        _achievements?.checkAndUnlockAchievements();

        // Donate intent for Siri to suggest starting another task
    SiriService().donateTaskCompleted(task.title);

        if (currentStreak >= 2) {
          _notifications?.scheduleStreakReminder(currentStreak);
        }
      }

  /// Check if user can break down current step (has remaining free uses or is premium)
  bool get canBreakDownForFree => canDecompose;

  /// Remaining free breakdowns (global lifetime limit). -1 means unlimited.
  int get remainingFreeBreakdowns => remainingFreeDecompositions;

  /// Break down the current step into smaller sub-steps using AI
  /// Returns false if user hit the limit and isn't premium
  Future<bool> breakDownCurrentStep() async {
    if (_activeTask == null || _activeTask!.currentStep == null) {
      throw Exception('No active step to break down');
    }

    if (!canDecompose) {
      return false; // Signal that user hit the limit
    }

    final currentStep = _activeTask!.currentStep!;

    // Don't allow breaking down if already has substeps
    if (currentStep.hasSubSteps) {
      throw Exception('This step is already broken down');
    }

    // Get sub-steps from AI (pass task title as context)
    final apiKey = _settings?.openAIApiKey;
    final taskContext = _activeTask!.title;
    final List<TaskStep> subSteps;
    try {
      subSteps = await _withPremiumRetry(() => _aiService.getSubSteps(
      currentStep.action,
      apiKey,
            taskContext: taskContext,
          ));
    } on RateLimitException catch (e) {
      if (e.isFreeLimitReached) {
        _settings?.markFreeLimitReached();
        notifyListeners();
        return false;
      }
      rethrow;
    }

    if (subSteps.isEmpty) {
      throw Exception('Could not break down this step further');
    }

    // Counts against the same lifetime free allowance as task breakdowns
    _recordAiUsage();

    // Store substeps inside the current step (not replacing in main list)
    currentStep.subSteps = subSteps;
    currentStep.currentSubStepIndex = 0;

    // Save and notify
    await _saveTasks();
    _updateWidget();
    notifyListeners();

    return true;
  }

  /// Update home screen widget with current task data
  Future<void> _updateWidget() async {
    await WidgetService.updateCurrentTask(_activeTask);
  }

  Future<List<TaskStep>> getSubSteps(String stepAction) async {
    final apiKey = _settings?.openAIApiKey;
    return _aiService.getSubSteps(stepAction, apiKey);
  }

  /// Removes a task. Returns a callback that puts it back (for "Undo"),
  /// or null if no task had that id.
  VoidCallback? deleteTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return null;
    final removed = _tasks.removeAt(index);
    if (_activeTask?.id == taskId) {
      _activeTask = null;
      _notifications?.clearUnfinishedTaskReminder();
    }
    _saveTasks();
    notifyListeners();

    return () {
      if (_tasks.any((t) => t.id == removed.id)) return;
      _tasks.insert(index.clamp(0, _tasks.length), removed);
      _saveTasks();
      notifyListeners();
    };
  }

  /// Starts [routine] and makes it the active task. Resumes today's
  /// unfinished run instead of adding a duplicate; unfinished runs from
  /// earlier days are dropped so the routine starts fresh.
  Task startRoutine(Routine routine) {
    final prefix = 'routine_${routine.id}_';
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    Task? task;
    final before = _tasks.length;
    _tasks.removeWhere((t) {
      if (!t.id.startsWith(prefix) || t.isCompleted) return false;
      if (task == null && isToday(t.createdAt)) {
        task = t;
        return false;
      }
      return true;
    });

    final resumed = task;
    final Task result;
    if (resumed != null) {
      result = resumed;
      if (_tasks.length != before) _saveTasks();
    } else {
      result = routine.toTask();
      _tasks.insert(0, result);
      _saveTasks();
    }
    setActiveTask(result);
    return result;
  }

  /// Add a task from a template (no AI decomposition needed)
  void addTask(Task task) {
    _tasks.insert(0, task);
    _saveTasks();
    notifyListeners();
  }

  /// Removes every task. Returns a callback that restores them (for "Undo").
  VoidCallback clearAllTasks() {
    final removed = List<Task>.of(_tasks);
    _tasks.clear();
    _activeTask = null;
    _notifications?.clearUnfinishedTaskReminder();
    _saveTasks();
    notifyListeners();

    return () {
      final existingIds = _tasks.map((t) => t.id).toSet();
      _tasks.addAll(removed.where((t) => !existingIds.contains(t.id)));
      _saveTasks();
      notifyListeners();
    };
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Record timer usage for stats tracking
  void recordTimerUsage(int minutes) {
    _stats?.recordTimerUsage(minutes);
    _usedTimerThisTask = true;
    _achievements?.checkAndUnlockAchievements();
  }

  /// Record pomodoro completion for stats tracking
  void recordPomodoroCompleted() {
    _stats?.recordPomodoroCompleted();
    _achievements?.checkAndUnlockAchievements();
  }

  /// Record time spent in Body Double mode for stats tracking
  void recordBodyDoubleMinutes(int minutes) {
    _stats?.recordBodyDoubleMinutes(minutes);
  }

  /// Record template usage for stats tracking
  void recordTemplateUsed(String templateId) {
    _stats?.recordTemplateUsed(templateId);
    _isFromTemplate = true;
    _achievements?.checkAndUnlockAchievements();
  }
}
