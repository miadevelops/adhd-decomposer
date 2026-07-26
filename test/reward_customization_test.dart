import 'package:adhd_decomposer/core/theme/app_theme.dart';
import 'package:adhd_decomposer/data/services/sound_service.dart';
import 'package:adhd_decomposer/presentation/screens/level_progression_screen.dart';
import 'package:adhd_decomposer/presentation/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reward themes apply distinct light and dark palettes', () {
    final defaultLight = AppTheme.lightThemeFor('default');
    final sunsetLight = AppTheme.lightThemeFor('sunset_coral');
    final sunsetDark = AppTheme.darkThemeFor('sunset_coral');

    expect(sunsetLight.colorScheme.primary,
        isNot(defaultLight.colorScheme.primary));
    expect(sunsetLight.scaffoldBackgroundColor, const Color(0xFFFFF8F6));
    expect(sunsetDark.scaffoldBackgroundColor, const Color(0xFF201416));
  });

  testWidgets('stats share card uses the app icon asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: StatsShareCard(
            tasksCompleted: 3,
            currentStreak: 1,
            totalSteps: 22,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/icons/app_icon_1024.png',
    );
  });

  test('celebration sound rewards map to bundled assets', () async {
    const expectedAssets = {
      'default': 'sounds/task_complete.mp3',
      'arcade': 'sounds/arcade_chime.mp3',
      'nature': 'sounds/nature_chime.mp3',
      'magic': 'sounds/magic_chime.mp3',
    };

    for (final entry in expectedAssets.entries) {
      final asset = SoundService.celebrationAssetFor(entry.key);
      expect(asset, entry.value);
      expect(
        (await rootBundle.load('assets/$asset')).lengthInBytes,
        greaterThan(0),
      );
    }

    expect(
      SoundService.celebrationAssetFor('unknown'),
      expectedAssets['default'],
    );
  });

  test('level progression orders rewards and identifies their type', () {
    final rewards = buildLevelRewards();
    final arcade = rewards.singleWhere((reward) => reward.name == 'Arcade');

    expect(
      rewards.map((reward) => reward.level),
      orderedEquals(rewards.map((reward) => reward.level).toList()..sort()),
    );
    expect(arcade.level, 4);
    expect(arcade.type, LevelRewardType.celebrationSound);
    expect(arcade.type.label, 'Celebration sound');
  });
}
