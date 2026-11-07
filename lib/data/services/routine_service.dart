import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/routine.dart';
import '../models/task.dart';
import 'json_list_storage.dart';

/// Service for managing recurring routines
class RoutineService extends ChangeNotifier {
  static const String _boxName = 'routines';
  
  List<Routine> _routines = [];
  bool _initialized = false;
  
  List<Routine> get routines => _routines;
  
  /// Get routines that are due today (not yet completed)
  List<Routine> get routinesDueToday => 
      _routines.where((r) => r.isDueToday()).toList();
  
  /// Get routines completed today
  List<Routine> get routinesCompletedToday =>
      _routines.where((r) => r.isCompletedToday()).toList();
  
  /// Get count of pending routines for today
  int get pendingCount => routinesDueToday.length;
  
  /// Check if there are any routines due
  bool get hasRoutinesDue => routinesDueToday.isNotEmpty;
  
  /// Get morning routines (preferred time before noon)
  List<Routine> get morningRoutines => _routines.where((r) => 
      r.preferredTime.hour < 12).toList();
  
  /// Get evening routines (preferred time after 6pm)
  List<Routine> get eveningRoutines => _routines.where((r) => 
      r.preferredTime.hour >= 18).toList();
  
  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final box = await Hive.openBox<String>(_boxName);
      _routines = await JsonListStorage.load(box, 'routinesList', Routine.fromJson);
      _initialized = true;
    } catch (e) {
      debugPrint('Error loading routines: $e');
      _routines = [];
    }
    notifyListeners();
  }
  
  /// Save routines to storage
  Future<void> _saveRoutines() async {
    // Never overwrite stored routines we failed to read
    if (!_initialized) {
      debugPrint('RoutineService: skipping save because routines failed to load');
      return;
    }
    try {
      final box = await Hive.openBox<String>(_boxName);
      final encoded = JsonListStorage.encode(_routines, (Routine r) => r.toJson());
      await box.put('routinesList', encoded);
    } catch (e) {
      debugPrint('Error saving routines: $e');
    }
  }
  
  /// Add a new routine
  Future<void> addRoutine(Routine routine) async {
    _routines.insert(0, routine);
    await _saveRoutines();
    notifyListeners();
  }
  
  /// Update an existing routine
  Future<void> updateRoutine(Routine routine) async {
    final index = _routines.indexWhere((r) => r.id == routine.id);
    if (index != -1) {
      _routines[index] = routine;
      await _saveRoutines();
      notifyListeners();
    }
  }
  
  /// Delete a routine
  Future<void> deleteRoutine(String routineId) async {
    _routines.removeWhere((r) => r.id == routineId);
    await _saveRoutines();
    notifyListeners();
  }
  
  /// Mark a routine as complete for today
  Future<void> markRoutineComplete(String routineId) async {
    final index = _routines.indexWhere((r) => r.id == routineId);
    if (index != -1) {
      if (!_routines[index].markComplete()) return;
      await _saveRoutines();
      notifyListeners();
    }
  }
  
  /// Get a routine by ID
  Routine? getRoutine(String routineId) {
    try {
      return _routines.firstWhere((r) => r.id == routineId);
    } catch (_) {
      return null;
    }
  }
  
  /// Create a routine from a completed task
  Future<Routine> createFromTask(
    Task task, {
    required RecurrenceType recurrence,
    required TimeOfDay preferredTime,
    List<int>? daysOfWeek,
    int? dayOfMonth,
  }) async {
    // Create fresh steps without completion status
    final freshSteps = task.steps.map((s) => TaskStep(
      id: s.id,
      action: s.action,
      estimatedMinutes: s.estimatedMinutes,
      subSteps: s.subSteps?.map((sub) => TaskStep(
        id: sub.id,
        action: sub.action,
        estimatedMinutes: sub.estimatedMinutes,
      )).toList(),
    )).toList();
    
    final routine = Routine(
      id: 'routine_${DateTime.now().millisecondsSinceEpoch}',
      name: task.title,
      steps: freshSteps,
      recurrence: recurrence,
      preferredTime: preferredTime,
      daysOfWeek: daysOfWeek ?? [],
      dayOfMonth: dayOfMonth,
      totalEstimatedMinutes: task.totalEstimatedMinutes,
    );
    
    await addRoutine(routine);
    return routine;
  }
  
  /// Get streak information for display
  Map<String, dynamic> getStreakInfo() {
    int totalStreaks = 0;
    int longestStreak = 0;
    int routinesWithStreaks = 0;
    
    for (final routine in _routines) {
      if (routine.completionStreak > 0) {
        routinesWithStreaks++;
        totalStreaks += routine.completionStreak;
        if (routine.completionStreak > longestStreak) {
          longestStreak = routine.completionStreak;
        }
      }
    }
    
    return {
      'totalStreaks': totalStreaks,
      'longestStreak': longestStreak,
      'routinesWithStreaks': routinesWithStreaks,
      'totalRoutines': _routines.length,
    };
  }
  
  /// Check if user has any streaks worth celebrating (7+ days)
  bool get hasStreakCelebration => 
      _routines.any((r) => r.completionStreak >= 7);
  
  /// Get routines with active streaks (7+ days)
  List<Routine> get celebratoryStreaks =>
      _routines.where((r) => r.completionStreak >= 7).toList();
}
