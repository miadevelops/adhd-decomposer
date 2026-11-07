import 'dart:io';

import 'package:adhd_decomposer/data/services/achievements_service.dart';
import 'package:adhd_decomposer/data/services/calendar_service.dart';
import 'package:adhd_decomposer/data/services/notification_service.dart';
import 'package:adhd_decomposer/data/services/purchase_service.dart';
import 'package:adhd_decomposer/data/services/routine_service.dart';
import 'package:adhd_decomposer/data/services/settings_service.dart';
import 'package:adhd_decomposer/data/services/stats_service.dart';
import 'package:adhd_decomposer/data/services/xp_service.dart';
import 'package:adhd_decomposer/main.dart';
import 'package:adhd_decomposer/presentation/providers/theme_provider.dart';
import 'package:adhd_decomposer/presentation/screens/home_screen.dart';
import 'package:adhd_decomposer/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;
  late SettingsService settings;
  late StatsService stats;
  late AchievementsService achievements;
  late RoutineService routines;
  late XPService xpService;
  late ThemeProvider themeProvider;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The home_widget plugin isn't available on the test host.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'), (call) async => null);
    messenger.setMockStreamHandler(
      const EventChannel('home_widget/updates'),
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );

    hiveDirectory = await Directory.systemTemp.createTemp('widget_test');
    Hive.init(hiveDirectory.path);

    settings = SettingsService();
    await settings.initialize();
    stats = StatsService();
    await stats.initialize();
    achievements = AchievementsService();
    await achievements.initialize(stats);
    routines = RoutineService();
    await routines.initialize();
    xpService = XPService();
    await xpService.initialize();
    themeProvider = ThemeProvider();
    await themeProvider.initialize();
    // Opened here, outside the fake-async test zone, so TaskProvider reuses
    // it; a box opened inside a widget test can never be closed.
    await Hive.openBox<String>('tasks');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  // Platform-channel services (notifications, calendar, purchases) are left
  // uninitialized, as they would be if their startup step failed.
  Widget buildApp() => ADHDDecomposerApp(
        settings: settings,
        stats: stats,
        achievements: achievements,
        notifications: NotificationService(),
        calendar: CalendarService(),
        routines: routines,
        purchases: PurchaseService(),
        xpService: xpService,
        themeProvider: themeProvider,
      );

  // Hive writes started inside the fake-async test zone only complete once
  // real IO has run and the fake zone is pumped again. Drain them so that
  // Hive.close() in tearDownAll doesn't wait forever.
  // Writes made in the real zone complete normally.
  Future<void> setOnboardingComplete(WidgetTester tester, bool value) =>
      tester.runAsync(() async {
        settings.onboardingComplete = value;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

  Future<void> unmountAndDrain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  testWidgets('a fresh install starts on onboarding', (tester) async {
    await setOnboardingComplete(tester, false);
    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await unmountAndDrain(tester);
  });

  testWidgets('a returning user starts on the home screen', (tester) async {
    await setOnboardingComplete(tester, true);
    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    await unmountAndDrain(tester);
  });
}
