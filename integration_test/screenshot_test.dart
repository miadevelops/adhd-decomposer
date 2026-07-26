import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:adhd_decomposer/main.dart' as app;

/// Screenshot integration test for App Store / Play Store
///
/// Run with:
///   flutter test integration_test/screenshot_test.dart
///
/// Or for specific device:
///   flutter test integration_test/screenshot_test.dart -d <device_id>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Store Screenshots', () {
    testWidgets('Capture all screens', (WidgetTester tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Helper to take screenshot
      Future<void> takeScreenshot(String name) async {
        await tester.pumpAndSettle();

        // For Android
        if (Platform.isAndroid) {
          await binding.takeScreenshot(name);
        }
        // For iOS, screenshots are captured differently
        // This creates a file we can use
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }

      // 1. Welcome / Onboarding (if shown)
      await takeScreenshot('01_welcome');

      // Check if we're on onboarding
      final getStartedButton = find.text('Get Started');
      if (getStartedButton.evaluate().isNotEmpty) {
        await takeScreenshot('01_welcome');

        await tester.tap(getStartedButton);
        await tester.pumpAndSettle();
        await takeScreenshot('02_challenge');

        // Select a challenge
        final challengeOption = find.text('Starting tasks');
        if (challengeOption.evaluate().isNotEmpty) {
          await tester.tap(challengeOption);
          await tester.pumpAndSettle();
        }

        final continueButton = find.text('Continue');
        if (continueButton.evaluate().isNotEmpty) {
          await tester.tap(continueButton);
          await tester.pumpAndSettle();
        }

        // Skip through remaining onboarding
        for (var i = 0; i < 5; i++) {
          final skipOrContinue =
              find.textContaining(RegExp(r'Continue|Skip|Get Started|Start'));
          if (skipOrContinue.evaluate().isNotEmpty) {
            await tester.tap(skipOrContinue.first);
            await tester.pumpAndSettle();
          }
        }
      }

      // 2. Home screen
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeScreenshot('03_home');

      // 3. Tap New Task
      final newTaskButton = find.text('New Task');
      if (newTaskButton.evaluate().isNotEmpty) {
        await tester.tap(newTaskButton);
        await tester.pumpAndSettle();
        await takeScreenshot('04_new_task');

        // Type a task
        final textField = find.byType(TextField).first;
        await tester.enterText(textField, 'Clean my room before guests arrive');
        await tester.pumpAndSettle();
        await takeScreenshot('04_new_task_typed');

        // Tap break it down
        final breakDownButton = find.text('Break it down');
        if (breakDownButton.evaluate().isNotEmpty) {
          await tester.tap(breakDownButton);
          // Wait for AI response (mock should be instant)
          await tester.pumpAndSettle(const Duration(seconds: 3));
          await takeScreenshot('05_breakdown');
        }

        // Start the task
        final startButton = find.text('Start');
        if (startButton.evaluate().isNotEmpty) {
          await tester.tap(startButton);
          await tester.pumpAndSettle();
          await takeScreenshot('06_execute');

          // Complete a step to show progress
          final doneButton = find.text('Done!');
          if (doneButton.evaluate().isNotEmpty) {
            await tester.tap(doneButton);
            await tester.pumpAndSettle(const Duration(seconds: 2));
            await takeScreenshot('06_execute_progress');
          }

          // Go back
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          } else {
            // Try navigator pop
            await tester.pageBack();
            await tester.pumpAndSettle();
          }
        }
      }

      // 4. Templates
      final templatesButton = find.text('Templates');
      if (templatesButton.evaluate().isNotEmpty) {
        await tester.tap(templatesButton);
        await tester.pumpAndSettle();
        await takeScreenshot('07_templates');

        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      // 5. Progress (via level badge)
      final progressBadge = find.bySemanticsLabel(
        RegExp(r'Level \d+\. Tap to view progress'),
      );
      if (progressBadge.evaluate().isNotEmpty) {
        await tester.tap(progressBadge);
        await tester.pumpAndSettle();
        await takeScreenshot('08_stats');

        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      // 6. Settings
      final settingsIcon = find.byIcon(Icons.settings_outlined);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon);
        await tester.pumpAndSettle();
        await takeScreenshot('09_settings');
      }

      // Done!
      debugPrint('Screenshots complete!');
    });
  });
}
