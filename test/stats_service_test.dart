import 'dart:io';

import 'package:adhd_decomposer/data/services/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('stats_service_test');
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('task completion does not count completed steps twice', () async {
    final stats = StatsService();
    await stats.initialize();

    stats.recordStepCompletion();
    stats.recordTaskCompletion();

    expect(stats.totalTasksCompleted, 1);
    expect(stats.totalStepsCompleted, 1);
  });

  test('current streak reads as 0 once a day has been missed', () async {
    final stats = StatsService();
    await stats.initialize();

    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();

    stats.currentStreak = 4;
    stats.lastCompletionDate = key(DateTime(now.year, now.month, now.day - 1));
    expect(stats.currentStreak, 4);

    stats.lastCompletionDate = key(DateTime(now.year, now.month, now.day - 2));
    expect(stats.currentStreak, 0);

    stats.recordTaskCompletion();
    expect(stats.currentStreak, 1);
  });

  test('cached JSON values stay correct across writes and caller edits',
      () async {
    final stats = StatsService();
    await stats.initialize();

    stats.templatesUsed = {'a'};
    expect(stats.templatesUsed, {'a'});

    // Mutating a returned value must not leak into the cache.
    stats.templatesUsed.add('b');
    stats.dailyCompletions['2020-01-01'] = 9;
    expect(stats.templatesUsed, {'a'});
    expect(stats.dailyCompletions.containsKey('2020-01-01'), isFalse);

    stats.templatesUsed = {'a', 'c'};
    expect(stats.templatesUsed, {'a', 'c'});

    // A write that bypasses the setter is still picked up.
    await Hive.box('stats')
        .put(StatsService.keyDailyCompletions, '{"2020-01-02":3}');
    expect(stats.dailyCompletions, {'2020-01-02': 3});
  });
}
