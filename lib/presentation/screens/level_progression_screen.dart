import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/player_profile.dart';
import '../../data/services/xp_service.dart';

enum LevelRewardType {
  title('Title', Icons.military_tech_outlined),
  theme('App theme', Icons.palette_outlined),
  celebrationSound('Celebration sound', Icons.music_note_outlined);

  final String label;
  final IconData icon;

  const LevelRewardType(this.label, this.icon);
}

class LevelRewardInfo {
  final String name;
  final String emoji;
  final int level;
  final LevelRewardType type;

  const LevelRewardInfo({
    required this.name,
    required this.emoji,
    required this.level,
    required this.type,
  });
}

List<LevelRewardInfo> buildLevelRewards() {
  return [
    ...PlayerTitle.all.map(
      (title) => LevelRewardInfo(
        name: title.title,
        emoji: title.emoji,
        level: title.requiredLevel,
        type: LevelRewardType.title,
      ),
    ),
    ...UnlockableTheme.all.map(
      (theme) => LevelRewardInfo(
        name: theme.name,
        emoji: theme.emoji,
        level: theme.requiredLevel,
        type: LevelRewardType.theme,
      ),
    ),
    ...UnlockableSound.all.map(
      (sound) => LevelRewardInfo(
        name: sound.name,
        emoji: sound.emoji,
        level: sound.requiredLevel,
        type: LevelRewardType.celebrationSound,
      ),
    ),
  ]..sort((a, b) {
      final levelComparison = a.level.compareTo(b.level);
      if (levelComparison != 0) return levelComparison;
      return a.type.index.compareTo(b.type.index);
    });
}

class LevelProgressionScreen extends StatelessWidget {
  const LevelProgressionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final xpService = context.watch<XPService>();
    final rewards = buildLevelRewards();
    final levels = rewards.map((reward) => reward.level).toSet().toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Level progression')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CurrentLevelSummary(xpService: xpService),
          const SizedBox(height: 24),
          Text(
            'Unlock roadmap',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Level up to unlock new titles, app themes, and celebration sounds.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...levels.map((level) {
            final levelRewards = rewards
                .where((reward) => reward.level == level)
                .toList(growable: false);
            return _LevelMilestone(
              level: level,
              rewards: levelRewards,
              currentLevel: xpService.level,
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CurrentLevelSummary extends StatelessWidget {
  final XPService xpService;

  const _CurrentLevelSummary({required this.xpService});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xpRemaining =
        (xpService.xpForNextLevel - xpService.totalXP).clamp(0, 1000000);

    return Card(
      color: colorScheme.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: Text(
                    '${xpService.level}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT LEVEL',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        xpService.currentTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: xpService.progressToNextLevel,
                minHeight: 10,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$xpRemaining XP to Level ${xpService.level + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelMilestone extends StatelessWidget {
  final int level;
  final List<LevelRewardInfo> rewards;
  final int currentLevel;

  const _LevelMilestone({
    required this.level,
    required this.rewards,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = currentLevel >= level;
    final isCurrent = currentLevel == level;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              border: isCurrent
                  ? Border.all(color: colorScheme.primary, width: 3)
                  : null,
            ),
            child: isUnlocked
                ? Text(
                    '$level',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(Icons.lock_outline,
                    size: 20, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              color: isCurrent
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Level $level',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const Spacer(),
                        if (isCurrent)
                          Text(
                            'CURRENT',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          )
                        else if (isUnlocked)
                          Icon(Icons.check_circle,
                              color: colorScheme.primary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...rewards.map(
                      (reward) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              isUnlocked ? reward.emoji : '🔒',
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reward.name,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  Row(
                                    children: [
                                      Icon(reward.type.icon,
                                          size: 14,
                                          color: colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        reward.type.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
