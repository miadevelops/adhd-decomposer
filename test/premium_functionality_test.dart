import 'dart:io';

import 'package:adhd_decomposer/data/services/purchase_service.dart';
import 'package:adhd_decomposer/data/services/settings_service.dart';
import 'package:adhd_decomposer/presentation/providers/task_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'premium_functionality_test',
    );
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('debug entitlement unlocks premium task limits', () async {
    final settings = SettingsService();
    await settings.initialize();
    settings.decompositionCount = SettingsService.freeDecompositionLimit;
    settings.isPremium = false;

    final purchases = PurchaseService();
    purchases.setDebugPremiumOverride(true);

    final provider = TaskProvider(
      settings: settings,
      purchases: purchases,
    );

    expect(provider.isPremium, isTrue);
    expect(provider.canDecompose, isTrue);
    expect(provider.canBreakDownForFree, isTrue);
    expect(provider.remainingFreeDecompositions, -1);
    expect(provider.remainingFreeBreakdowns, -1);
  });

  test('debug entitlement notifies premium feature consumers', () {
    final purchases = PurchaseService();
    var notifications = 0;
    purchases.addListener(() => notifications++);

    purchases.setDebugPremiumOverride(true);

    expect(purchases.isPremium, isTrue);
    expect(notifications, 1);
  });
}