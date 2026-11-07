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
}
