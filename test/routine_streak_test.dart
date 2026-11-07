import 'package:adhd_decomposer/data/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Routine _routine({
  RecurrenceType recurrence = RecurrenceType.daily,
  List<int> daysOfWeek = const [],
  DateTime? lastCompleted,
  int streak = 0,
}) {
  return Routine(
    id: 'r1',
    name: 'Morning',
    steps: const [],
    recurrence: recurrence,
    preferredTime: const TimeOfDay(hour: 8, minute: 0),
    daysOfWeek: daysOfWeek,
    lastCompleted: lastCompleted,
    completionStreak: streak,
  );
}

DateTime _daysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days, 12);
}

void main() {
  test('completing twice on the same day does not inflate the streak', () {
    final routine = _routine();

    expect(routine.markComplete(), isTrue);
    expect(routine.completionStreak, 1);
    expect(routine.markComplete(), isFalse);
    expect(routine.completionStreak, 1);
  });

  test('daily streak continues from yesterday', () {
    final routine = _routine(lastCompleted: _daysAgo(1), streak: 3);

    expect(routine.completionStreak, 3);
    routine.markComplete();
    expect(routine.completionStreak, 4);
  });

  test('daily streak reads as broken after a missed day', () {
    final routine = _routine(lastCompleted: _daysAgo(2), streak: 3);

    expect(routine.completionStreak, 0);
    routine.markComplete();
    expect(routine.completionStreak, 1);
  });

  test('weekly streak survives unscheduled days in between', () {
    final today = DateTime.now();
    final lastWeek = _daysAgo(7);
    // Scheduled only on today's weekday, so the previous occurrence is 7 days ago.
    final routine = _routine(
      recurrence: RecurrenceType.weekly,
      daysOfWeek: [today.weekday],
      lastCompleted: lastWeek,
      streak: 2,
    );

    expect(routine.completionStreak, 2);
    routine.markComplete();
    expect(routine.completionStreak, 3);
  });

  test('weekly streak breaks when a scheduled occurrence is missed', () {
    final today = DateTime.now();
    final routine = _routine(
      recurrence: RecurrenceType.weekly,
      daysOfWeek: [today.weekday],
      lastCompleted: _daysAgo(14),
      streak: 2,
    );

    expect(routine.completionStreak, 0);
  });
}
