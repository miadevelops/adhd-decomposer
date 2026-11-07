import 'package:hive_flutter/hive_flutter.dart';
import 'ai_service.dart';
import '../models/coach.dart';
import '../coaches.dart';

/// Ambient sound options for Body Double mode
enum DefaultAmbientSound {
  none,
  cafe,
  rain,
  whiteNoise,
}

/// Service for managing app settings persistence
class SettingsService {
  static const String _boxName = 'settings';
  
  // Settings keys
  static const String keyOnboardingComplete = 'onboardingComplete';
  static const String keyUserName = 'userName';
  static const String keyUserChallenge = 'userChallenge';
  static const String keySoundEnabled = 'soundEnabled';
  static const String keyHapticEnabled = 'hapticEnabled';
  static const String keyConfettiEnabled = 'confettiEnabled';
  static const String keyCelebrationSoundEnabled = 'celebrationSoundEnabled';
  static const String keyDecompositionCount = 'decompositionCount';
  static const String keyIsPremium = 'isPremium';
  static const String keyOpenAIApiKey = 'openAIApiKey';
  static const String keyDecompositionStyle = 'decompositionStyle';
  static const String keyDefaultAmbientSound = 'defaultAmbientSound';
  static const String keySelectedCoach = 'selectedCoach';
  
  // Rate app settings
  static const String keyHasRated = 'hasRated';
  static const String keyRateAskedCount = 'rateAskedCount';
  static const String keyTasksSinceLastAsk = 'tasksSinceLastAsk';
  
  // Accessibility settings
  static const String keyReduceAnimations = 'reduceAnimations';
  static const String keyAutoAdvanceEnabled = 'autoAdvanceEnabled';
  
  // Display settings
  static const String keyShowCompletedTasks = 'showCompletedTasks';
  
  // Calendar settings
  static const String keyCalendarEnabled = 'calendarEnabled';
  static const String keyDefaultCalendarId = 'defaultCalendarId';
  static const String keyDefaultReminderMinutes = 'defaultReminderMinutes';
  
  static const int freeDecompositionLimit = 5;
  static const int tasksBeforeFirstAsk = 5;
  static const int tasksBetweenAsks = 5;
  static const int maxAskCount = 3;
  
  Box<dynamic>? _box;
  
  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
  }
  
  Box<dynamic> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('SettingsService not initialized. Call initialize() first.');
    }
    return _box!;
  }
  
  // Onboarding
  bool get onboardingComplete => _safeBox.get(keyOnboardingComplete, defaultValue: false);
  set onboardingComplete(bool value) => _safeBox.put(keyOnboardingComplete, value);
  
  // User info
  String? get userName => _safeBox.get(keyUserName);
  set userName(String? value) => _safeBox.put(keyUserName, value);
  
  String? get userChallenge => _safeBox.get(keyUserChallenge);
  set userChallenge(String? value) => _safeBox.put(keyUserChallenge, value);
  
  // Feedback settings
  bool get soundEnabled => _safeBox.get(keySoundEnabled, defaultValue: true);
  set soundEnabled(bool value) => _safeBox.put(keySoundEnabled, value);
  
  bool get hapticEnabled => _safeBox.get(keyHapticEnabled, defaultValue: true);
  set hapticEnabled(bool value) => _safeBox.put(keyHapticEnabled, value);
  
  bool get confettiEnabled => _safeBox.get(keyConfettiEnabled, defaultValue: true);
  set confettiEnabled(bool value) => _safeBox.put(keyConfettiEnabled, value);
  
  bool get celebrationSoundEnabled => _safeBox.get(keyCelebrationSoundEnabled, defaultValue: true);
  set celebrationSoundEnabled(bool value) => _safeBox.put(keyCelebrationSoundEnabled, value);
  
  // Usage tracking
  int get decompositionCount => _safeBox.get(keyDecompositionCount, defaultValue: 0);
  set decompositionCount(int value) => _safeBox.put(keyDecompositionCount, value);
  
  void incrementDecompositionCount() {
    decompositionCount = decompositionCount + 1;
  }

  /// Adopt the server's lifetime usage count (the backend is authoritative).
  void syncDecompositionCount(int serverUsed) {
    if (serverUsed >= 0 && serverUsed != decompositionCount) {
      decompositionCount = serverUsed;
    }
  }

  /// Called when the server reports the free allowance is used up.
  void markFreeLimitReached() {
    if (decompositionCount < freeDecompositionLimit) {
      decompositionCount = freeDecompositionLimit;
    }
  }
  
  bool get hasReachedFreeLimit => !isPremium && decompositionCount >= freeDecompositionLimit;
  
  // Premium status (cached locally, verified via PurchaseService on launch)
  // Note: This is a cache - the source of truth is PurchaseService.isPremium
  bool get isPremium => _safeBox.get(keyIsPremium, defaultValue: false);
  set isPremium(bool value) => _safeBox.put(keyIsPremium, value);
  
  /// Sync premium status from PurchaseService
  /// Call this after PurchaseService initialization
  void syncPremiumStatus(bool isPremiumFromPurchases) {
    if (isPremium != isPremiumFromPurchases) {
      isPremium = isPremiumFromPurchases;
    }
  }
  
  // API key (power user feature)
  String? get openAIApiKey => _safeBox.get(keyOpenAIApiKey);
  set openAIApiKey(String? value) => _safeBox.put(keyOpenAIApiKey, value);
  
  bool get hasCustomApiKey => openAIApiKey != null && openAIApiKey!.isNotEmpty;
  
  // Decomposition style
  DecompositionStyle get decompositionStyle {
    final stored = _safeBox.get(keyDecompositionStyle, defaultValue: 'standard');
    switch (stored) {
      case 'quick':
        return DecompositionStyle.quick;
      case 'gentle':
        return DecompositionStyle.gentle;
      default:
        return DecompositionStyle.standard;
    }
  }
  
  set decompositionStyle(DecompositionStyle value) {
    String stringValue;
    switch (value) {
      case DecompositionStyle.quick:
        stringValue = 'quick';
        break;
      case DecompositionStyle.gentle:
        stringValue = 'gentle';
        break;
      case DecompositionStyle.standard:
        stringValue = 'standard';
        break;
    }
    _safeBox.put(keyDecompositionStyle, stringValue);
  }
  
  // Can decompose (premium, has custom API key, or hasn't hit limit)
  bool get canDecompose => isPremium || hasCustomApiKey || !hasReachedFreeLimit;
  
  int get remainingFreeDecompositions {
    if (isPremium || hasCustomApiKey) return -1; // Unlimited
    return (freeDecompositionLimit - decompositionCount).clamp(0, freeDecompositionLimit);
  }
  
  // Rate app tracking
  bool get hasRated => _safeBox.get(keyHasRated, defaultValue: false);
  set hasRated(bool value) => _safeBox.put(keyHasRated, value);
  
  int get rateAskedCount => _safeBox.get(keyRateAskedCount, defaultValue: 0);
  set rateAskedCount(int value) => _safeBox.put(keyRateAskedCount, value);
  
  int get tasksSinceLastAsk => _safeBox.get(keyTasksSinceLastAsk, defaultValue: 0);
  set tasksSinceLastAsk(int value) => _safeBox.put(keyTasksSinceLastAsk, value);
  
  /// Check if we should show the rate app prompt
  bool get shouldShowRatePrompt {
    if (hasRated) return false;
    if (rateAskedCount >= maxAskCount) return false;
    
    final totalTasks = tasksSinceLastAsk;
    if (rateAskedCount == 0) {
      // First time: ask after X tasks
      return totalTasks >= tasksBeforeFirstAsk;
    } else {
      // Subsequent times: ask after Y more tasks
      return totalTasks >= tasksBetweenAsks;
    }
  }
  
  /// Record that we asked for a rating
  void recordRatePromptShown() {
    rateAskedCount = rateAskedCount + 1;
    tasksSinceLastAsk = 0;
  }
  
  /// Record that user rated the app
  void recordUserRated() {
    hasRated = true;
  }
  
  /// Increment task count (called after task completion)
  void incrementTasksSinceLastAsk() {
    tasksSinceLastAsk = tasksSinceLastAsk + 1;
  }
  
  // Accessibility settings
  /// Reduce animations for users sensitive to motion
  bool get reduceAnimations => _safeBox.get(keyReduceAnimations, defaultValue: false);
  set reduceAnimations(bool value) => _safeBox.put(keyReduceAnimations, value);
  
  /// Auto-advance to next step after completion (can be disabled for accessibility)
  bool get autoAdvanceEnabled => _safeBox.get(keyAutoAdvanceEnabled, defaultValue: true);
  set autoAdvanceEnabled(bool value) => _safeBox.put(keyAutoAdvanceEnabled, value);
  
  // Display settings
  /// Show completed tasks on home screen
  bool get showCompletedTasks => _safeBox.get(keyShowCompletedTasks, defaultValue: true);
  set showCompletedTasks(bool value) => _safeBox.put(keyShowCompletedTasks, value);
  
  // Calendar settings
  /// Enable/disable calendar integration
  bool get calendarEnabled => _safeBox.get(keyCalendarEnabled, defaultValue: false);
  set calendarEnabled(bool value) => _safeBox.put(keyCalendarEnabled, value);
  
  /// Default calendar ID for creating events
  String? get defaultCalendarId => _safeBox.get(keyDefaultCalendarId);
  set defaultCalendarId(String? value) => _safeBox.put(keyDefaultCalendarId, value);
  
  /// Default reminder time in minutes before event
  int get defaultReminderMinutes => _safeBox.get(keyDefaultReminderMinutes, defaultValue: 5);
  set defaultReminderMinutes(int value) => _safeBox.put(keyDefaultReminderMinutes, value);
  
  // Body Double settings
  /// Default ambient sound for Body Double mode
  DefaultAmbientSound get defaultAmbientSound {
    final stored = _safeBox.get(keyDefaultAmbientSound, defaultValue: 'none');
    switch (stored) {
      case 'cafe':
        return DefaultAmbientSound.cafe;
      case 'rain':
        return DefaultAmbientSound.rain;
      case 'whiteNoise':
        return DefaultAmbientSound.whiteNoise;
      default:
        return DefaultAmbientSound.none;
    }
  }
  
  set defaultAmbientSound(DefaultAmbientSound value) {
    String stringValue;
    switch (value) {
      case DefaultAmbientSound.cafe:
        stringValue = 'cafe';
        break;
      case DefaultAmbientSound.rain:
        stringValue = 'rain';
        break;
      case DefaultAmbientSound.whiteNoise:
        stringValue = 'whiteNoise';
        break;
      case DefaultAmbientSound.none:
        stringValue = 'none';
        break;
    }
    _safeBox.put(keyDefaultAmbientSound, stringValue);
  }
  
  // AI Coach settings
  /// Selected AI coach personality
  CoachType get selectedCoachType {
    final stored = _safeBox.get(keySelectedCoach, defaultValue: 'default_');
    return Coaches.typeFromString(stored);
  }
  
  set selectedCoachType(CoachType value) {
    _safeBox.put(keySelectedCoach, Coaches.typeToString(value));
  }
  
  /// Get the currently selected coach
  Coach get selectedCoach => Coaches.getByType(selectedCoachType);
}
