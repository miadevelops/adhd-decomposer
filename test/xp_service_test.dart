import 'dart:io';

import 'package:adhd_decomposer/data/services/xp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('xp_service_test');
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('streak bonus is awarded at most once per day', () async {
    final xp = XPService();
    await xp.initialize();
    final before = xp.profile.totalXP;

    final first = xp.awardStreakBonus(3);
    final second = xp.awardStreakBonus(3);

    expect(first, isNotNull);
    expect(second, isNull);
    expect(xp.profile.totalXP, before + first!.amount);
  });
}
