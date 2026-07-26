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
}
