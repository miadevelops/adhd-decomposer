import 'dart:io';

import 'package:adhd_decomposer/data/services/achievements_service.dart';
import 'package:adhd_decomposer/data/services/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late StatsService stats;
  late AchievementsService achievements;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'achievements_progress_test',
    );
    Hive.init(hiveDirectory.path);
    stats = StatsService();
    await stats.initialize();
    achievements = AchievementsService();
    await achievements.initialize(stats);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('next achievement is the locked milestone closest to completion', () {
    stats.totalTasksCompleted = 3;
    stats.totalStepsCompleted = 22;
    achievements.unlockedAchievementIds = {'first_step'};

    final next = achievements.nextAchievement;

    expect(next?.id, 'getting_started');
    expect(achievements.progressFor(next!), 0.6);
    expect(achievements.progressLabelFor(next), '3 of 5 tasks');
  });

  test('achievement collection orders unlocked milestones before locked', () {
    achievements.unlockedAchievementIds = {'on_a_roll', 'first_step'};

    final ordered = achievements.orderedAchievementsWithStatus;

    expect(ordered.take(2).every((entry) => entry.$2), isTrue);
    expect(ordered.skip(2).every((entry) => !entry.$2), isTrue);
    expect(ordered.map((entry) => entry.$1.id).take(2), [
      'first_step',
      'on_a_roll',
    ]);
  });
}
