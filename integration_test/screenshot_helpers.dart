/// Helper utilities for screenshot tests.
/// 
/// Provides functions to set up the app state for visually appealing screenshots.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Extension on IntegrationTestWidgetsFlutterBinding for screenshot helpers.
extension ScreenshotExtension on IntegrationTestWidgetsFlutterBinding {
  /// Takes a screenshot and saves it to the screenshots/raw directory.
  /// 
  /// The [name] should be in format like '01_onboarding_en' and will be
  /// saved as '01_onboarding_en.png'.
  Future<void> takeScreenshotToFile(String name) async {
    // On Android, takeScreenshot converts the Flutter surface to an image on
    // first use; the driver handles saving.
    await takeScreenshot(name);
  }
}

/// Screenshot configuration for different device sizes.
class ScreenshotConfig {
  final String deviceName;
  final Size screenSize;
  final double pixelRatio;
  
  const ScreenshotConfig({
    required this.deviceName,
    required this.screenSize,
    required this.pixelRatio,
  });
  
  /// iPhone 6.7" (iPhone 14 Pro Max, iPhone 15 Pro Max)
  static const iPhone67 = ScreenshotConfig(
    deviceName: 'iPhone_6.7',
    screenSize: Size(430, 932),
    pixelRatio: 3.0,
  );
  
  /// iPhone 6.5" (iPhone 11 Pro Max, XS Max)
  static const iPhone65 = ScreenshotConfig(
    deviceName: 'iPhone_6.5',
    screenSize: Size(414, 896),
    pixelRatio: 3.0,
  );
  
  /// iPhone 5.5" (iPhone 8 Plus, 7 Plus, 6s Plus)
  static const iPhone55 = ScreenshotConfig(
    deviceName: 'iPhone_5.5',
    screenSize: Size(414, 736),
    pixelRatio: 3.0,
  );
  
  /// iPad Pro 12.9" (3rd gen and later)
  static const iPadPro129 = ScreenshotConfig(
    deviceName: 'iPad_Pro_12.9',
    screenSize: Size(1024, 1366),
    pixelRatio: 2.0,
  );
}

/// Creates a directory if it doesn't exist.
Future<void> ensureScreenshotDirectory() async {
  final dir = Directory('screenshots/raw');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

/// Waits for all animations to complete and the frame to settle.
Future<void> waitForAnimations(WidgetTester tester, {Duration? extra}) async {
  await tester.pumpAndSettle();
  if (extra != null) {
    await tester.pump(extra);
    await tester.pumpAndSettle();
  }
}
