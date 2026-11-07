import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/player_profile.dart';

/// XP reward types
enum XPRewardType {
  stepComplete,
  taskComplete,
  streakBonus,
  timerBonus,
  firstTaskOfDay,
  templateComplete,
}

/// XP reward event for tracking
class XPReward {
  final XPRewardType type;
  final int amount;
  final String description;
  final DateTime timestamp;

  XPReward({
    required this.type,
    required this.amount,
    required this.description,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Level up event
class LevelUpEvent {
  final int newLevel;
  final List<String> unlockedThemes;
  final List<String> unlockedSounds;
  final String? newTitle;

  LevelUpEvent({
    required this.newLevel,
    this.unlockedThemes = const [],
    this.unlockedSounds = const [],
    this.newTitle,
  });

  bool get hasUnlocks =>
      unlockedThemes.isNotEmpty ||
      unlockedSounds.isNotEmpty ||
      newTitle != null;
}

/// Service for managing XP and leveling system
class XPService extends ChangeNotifier {
  static const String _boxName = 'xp_data';
  static const String keyPlayerProfile = 'playerProfile';
  static const String keyLastCompletionDate = 'lastCompletionDate';
  static const String keyXPEarnedToday = 'xpEarnedToday';
  static const String keyXPEarnedThisWeek = 'xpEarnedThisWeek';
  static const String keyWeekStartDate = 'weekStartDate';
  static const String keyXPTodayDate = 'xpTodayDate';
  static const String keyLastStreakBonusDate = 'lastStreakBonusDate';

  // XP rewards
  static const int xpStepComplete = 10;
  static const int xpTaskComplete = 50;
  static const int xpStreakBonus = 25; // Per day of streak
  static const int xpTimerBonus = 15;
  static const int xpFirstTaskOfDay = 20;
  static const int xpTemplateComplete = 30;

  Box<dynamic>? _box;
  PlayerProfile _profile = PlayerProfile();
  LevelUpEvent? _pendingLevelUp;

  // Today tracking
  String? _lastCompletionDate;
  int _xpEarnedToday = 0;
  int _xpEarnedThisWeek = 0;
  String? _weekStartDate;
  String? _xpTodayDate;

  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
    _loadProfile();
    _loadDailyTracking();
  }

  Box<dynamic> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('XPService not initialized. Call initialize() first.');
    }
    return _box!;
  }

  void _loadProfile() {
    final stored = _safeBox.get(keyPlayerProfile);
    if (stored != null) {
      try {
        _profile =
            PlayerProfile.fromJson(jsonDecode(stored) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error loading player profile: $e');
        // Keep a copy so the next save doesn't destroy the player's progress
        const backupKey = '${keyPlayerProfile}_corrupt';
        if (_safeBox.get(backupKey) == null) _safeBox.put(backupKey, stored);
        _profile = PlayerProfile();
      }
    }
    _grantMissingUnlocks();
  }

  /// Grants unlockables at or below the current level that the profile is
  /// missing (e.g. items added in an app update after the user levelled past them).
  void _grantMissingUnlocks() {
    final themes = UnlockableTheme.all
        .where((t) =>
            t.requiredLevel <= _profile.level &&
            !_profile.unlockedThemes.contains(t.id))
        .map((t) => t.id)
        .toList();
    final sounds = UnlockableSound.all
        .where((s) =>
            s.requiredLevel <= _profile.level &&
            !_profile.unlockedSounds.contains(s.id))
        .map((s) => s.id)
        .toList();
    if (themes.isEmpty && sounds.isEmpty) return;
    _profile = _profile.copyWith(
      unlockedThemes: [..._profile.unlockedThemes, ...themes],
      unlockedSounds: [..._profile.unlockedSounds, ...sounds],
    );
    _saveProfile();
  }

  void _saveProfile() {
    _safeBox.put(keyPlayerProfile, jsonEncode(_profile.toJson()));
  }

  void _loadDailyTracking() {
    _lastCompletionDate = _safeBox.get(keyLastCompletionDate);
    _xpEarnedToday = _safeBox.get(keyXPEarnedToday, defaultValue: 0);
    _xpEarnedThisWeek = _safeBox.get(keyXPEarnedThisWeek, defaultValue: 0);
    _weekStartDate = _safeBox.get(keyWeekStartDate);
    // Older versions didn't store the day the counter belongs to; the last
    // task completion date was the closest proxy.
    _xpTodayDate = _safeBox.get(keyXPTodayDate) ?? _lastCompletionDate;
    _rollPeriods();
  }

  /// Resets the daily/weekly counters when the day or week has changed.
  void _rollPeriods() {
    final now = DateTime.now();
    final today = _dateToKey(now);
    if (_xpTodayDate != today) {
      _xpEarnedToday = 0;
      _xpTodayDate = today;
      _safeBox.put(keyXPEarnedToday, 0);
      _safeBox.put(keyXPTodayDate, today);
    }

    final weekStart = _getWeekStart(now);
    if (_weekStartDate != weekStart) {
      _xpEarnedThisWeek = 0;
      _weekStartDate = weekStart;
      _safeBox.put(keyXPEarnedThisWeek, 0);
      _safeBox.put(keyWeekStartDate, weekStart);
    }
  }

  /// Get current player profile
  PlayerProfile get profile => _profile;

  /// Get current level
  int get level => _profile.level;

  /// Get current XP within this level
  int get currentXP => _profile.currentXP;

  /// Get total XP earned all time
  int get totalXP => _profile.totalXP;

  /// Get current title
  String get currentTitle => _profile.currentTitle;

  /// Get XP earned today
  int get xpEarnedToday =>
      _xpTodayDate == _dateToKey(DateTime.now()) ? _xpEarnedToday : 0;

  /// Get XP earned this week
  int get xpEarnedThisWeek =>
      _weekStartDate == _getWeekStart(DateTime.now()) ? _xpEarnedThisWeek : 0;

  /// Get XP required for next level
  int get xpForNextLevel => getXPForLevel(_profile.level + 1);

  /// Get XP required to reach a specific level
  int getXPForLevel(int targetLevel) {
    if (targetLevel <= 1) return 0;
    if (targetLevel == 2) return 100;
    if (targetLevel == 3) return 250;
    if (targetLevel == 4) return 500;
    if (targetLevel == 5) return 1000;
    // Exponential growth after level 5
    // Each level requires ~50% more than previous
    double xp = 1000;
    for (int i = 5; i < targetLevel; i++) {
      xp *= 1.5;
    }
    return xp.round();
  }

  /// Get progress to next level (0.0 to 1.0)
  double get progressToNextLevel {
    final currentLevelXP = getXPForLevel(_profile.level);
    final nextLevelXP = getXPForLevel(_profile.level + 1);
    final xpIntoLevel = _profile.totalXP - currentLevelXP;
    final xpNeeded = nextLevelXP - currentLevelXP;
    if (xpNeeded <= 0) return 1.0;
    return (xpIntoLevel / xpNeeded).clamp(0.0, 1.0);
  }

  /// Check if there's a pending level up event to celebrate
  LevelUpEvent? get pendingLevelUp => _pendingLevelUp;

  /// Clear the pending level up event after celebration
  void clearPendingLevelUp() {
    _pendingLevelUp = null;
    notifyListeners();
  }

  /// Award XP for completing a step
  XPReward awardStepComplete() {
    return _awardXP(
      xpStepComplete,
      XPRewardType.stepComplete,
      'Step completed',
    );
  }

  /// Award XP for completing a task
  List<XPReward> awardTaskComplete(
      {bool usedTimer = false, bool isFromTemplate = false}) {
    final rewards = <XPReward>[];
    final today = _dateToKey(DateTime.now());

    // Base task completion XP
    rewards.add(_awardXP(
      xpTaskComplete,
      XPRewardType.taskComplete,
      'Task completed',
    ));

    // First task of day bonus
    if (_lastCompletionDate != today) {
      rewards.add(_awardXP(
        xpFirstTaskOfDay,
        XPRewardType.firstTaskOfDay,
        'First task of the day!',
      ));
    }

    // Timer bonus
    if (usedTimer) {
      rewards.add(_awardXP(
        xpTimerBonus,
        XPRewardType.timerBonus,
        'Used timer',
      ));
    }

    // Template bonus
    if (isFromTemplate) {
      rewards.add(_awardXP(
        xpTemplateComplete,
        XPRewardType.templateComplete,
        'Template task',
      ));
    }

    // Update last completion date
    _lastCompletionDate = today;
    _safeBox.put(keyLastCompletionDate, today);

    return rewards;
  }

  /// Award XP for maintaining a streak. Granted at most once per day so it
  /// can't be farmed by completing many small tasks; returns null otherwise.
  XPReward? awardStreakBonus(int streakDays) {
    final today = _dateToKey(DateTime.now());
    if (_safeBox.get(keyLastStreakBonusDate) == today) return null;
    _safeBox.put(keyLastStreakBonusDate, today);
    final bonus = xpStreakBonus * streakDays.clamp(1, 7); // Cap at 7 days bonus
    return _awardXP(
      bonus,
      XPRewardType.streakBonus,
      '$streakDays day streak!',
    );
  }

  XPReward _awardXP(int amount, XPRewardType type, String description) {
    final previousLevel = _profile.level;
    _rollPeriods();

    _profile = _profile.copyWith(
      currentXP: _profile.currentXP + amount,
      totalXP: _profile.totalXP + amount,
    );

    // Update daily/weekly tracking
    _xpEarnedToday += amount;
    _xpEarnedThisWeek += amount;
    _safeBox.put(keyXPEarnedToday, _xpEarnedToday);
    _safeBox.put(keyXPEarnedThisWeek, _xpEarnedThisWeek);

    // Check for level up
    _checkLevelUp(previousLevel);

    _saveProfile();
    notifyListeners();

    return XPReward(
      type: type,
      amount: amount,
      description: description,
    );
  }

  void _checkLevelUp(int previousLevel) {
    final newLevel = _calculateLevel(_profile.totalXP);

    if (newLevel > previousLevel) {
      final unlockedThemes = <String>[];
      final unlockedSounds = <String>[];
      String? newTitle;

      // Check what got unlocked between previous and new level
      for (int lvl = previousLevel + 1; lvl <= newLevel; lvl++) {
        // Check themes
        for (final theme in UnlockableTheme.all) {
          if (theme.requiredLevel == lvl &&
              !_profile.unlockedThemes.contains(theme.id)) {
            unlockedThemes.add(theme.id);
          }
        }

        // Check sounds
        for (final sound in UnlockableSound.all) {
          if (sound.requiredLevel == lvl &&
              !_profile.unlockedSounds.contains(sound.id)) {
            unlockedSounds.add(sound.id);
          }
        }

        // Check titles
        for (final title in PlayerTitle.all) {
          if (title.requiredLevel == lvl) {
            newTitle = title.title;
          }
        }
      }

      // Update profile with unlocks
      _profile = _profile.copyWith(
        level: newLevel,
        currentXP: _profile.totalXP - getXPForLevel(newLevel),
        unlockedThemes: [..._profile.unlockedThemes, ...unlockedThemes],
        unlockedSounds: [..._profile.unlockedSounds, ...unlockedSounds],
        currentTitle: newTitle ?? _profile.currentTitle,
      );

      // Set pending level up event for celebration
      _pendingLevelUp = LevelUpEvent(
        newLevel: newLevel,
        unlockedThemes: unlockedThemes,
        unlockedSounds: unlockedSounds,
        newTitle: newTitle,
      );
    }
  }

  int _calculateLevel(int totalXP) {
    int level = 1;
    while (getXPForLevel(level + 1) <= totalXP) {
      level++;
    }
    return level;
  }

  /// Select a theme (must be unlocked)
  bool selectTheme(String themeId) {
    if (_profile.unlockedThemes.contains(themeId)) {
      _profile = _profile.copyWith(selectedTheme: themeId);
      _saveProfile();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Select a celebration sound (must be unlocked)
  bool selectSound(String soundId) {
    if (_profile.unlockedSounds.contains(soundId)) {
      _profile = _profile.copyWith(selectedSound: soundId);
      _saveProfile();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Check if a theme is unlocked
  bool isThemeUnlocked(String themeId) {
    return _profile.unlockedThemes.contains(themeId);
  }

  /// Check if a sound is unlocked
  bool isSoundUnlocked(String soundId) {
    return _profile.unlockedSounds.contains(soundId);
  }

  /// Get the currently selected theme
  String get selectedTheme => _profile.selectedTheme;

  /// Get the currently selected sound
  String get selectedSound => _profile.selectedSound;

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getWeekStart(DateTime date) {
    // Get Monday of current week
    // Calendar arithmetic (not Duration) so DST changes can't shift the day.
    final monday =
        DateTime(date.year, date.month, date.day - (date.weekday - 1));
    return _dateToKey(monday);
  }
}
