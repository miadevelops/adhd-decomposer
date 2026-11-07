import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/achievements_service.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final achievements = context.watch<AchievementsService>();
    final ordered = achievements.orderedAchievementsWithStatus;
    final unlocked = ordered.where((entry) => entry.$2).toList();
    final locked = ordered.where((entry) => !entry.$2).toList();
    final nextAchievement = achievements.nextAchievement;

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CollectionSummary(
            unlocked: unlocked.length,
            total: achievements.totalCount,
          ),
          if (nextAchievement != null) ...[
            const SizedBox(height: 24),
            Text('Next milestone',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _AchievementDetailTile(
              achievement: nextAchievement,
              isUnlocked: false,
              progress: achievements.progressFor(nextAchievement),
              progressLabel: achievements.progressLabelFor(nextAchievement),
              emphasized: true,
            ),
          ],
          if (unlocked.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: 'Unlocked', count: unlocked.length),
            const SizedBox(height: 8),
            ...unlocked.map((entry) => _AchievementDetailTile(
                  achievement: entry.$1,
                  isUnlocked: true,
                )),
          ],
          if (locked.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: 'Locked', count: locked.length),
            const SizedBox(height: 8),
            ...locked.map((entry) => _AchievementDetailTile(
                  achievement: entry.$1,
                  isUnlocked: false,
                  progress: achievements.progressFor(entry.$1),
                  progressLabel: achievements.progressLabelFor(entry.$1),
                )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  final int unlocked;
  final int total;

  const _CollectionSummary({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : unlocked / total;

    return Card(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your collection',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  '$unlocked of $total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        Text('$count', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _AchievementDetailTile extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final double? progress;
  final String? progressLabel;
  final bool emphasized;

  const _AchievementDetailTile({
    required this.achievement,
    required this.isUnlocked,
    this.progress,
    this.progressLabel,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MergeSemantics(
      child: Semantics(
        label: isUnlocked ? 'Unlocked achievement' : 'Locked achievement',
        child: Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: emphasized ? colorScheme.primary.withValues(alpha: 0.08) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExcludeSemantics(
                child: Text(
                  isUnlocked ? achievement.icon : '🔒',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      if (isUnlocked)
                        Icon(Icons.check_circle,
                            color: colorScheme.primary, size: 20),
                    ],
                  ),
                  Text(
                    achievement.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (!isUnlocked && progress != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progressLabel ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
