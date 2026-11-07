import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../data/models/player_profile.dart';
import '../../data/services/stats_service.dart';
import '../../data/services/achievements_service.dart';
import '../../data/services/share_service.dart';
import '../../data/services/siri_service.dart';
import '../../data/services/xp_service.dart';
import '../widgets/share_card.dart';
import 'achievements_screen.dart';
import 'level_progression_screen.dart';
import 'personalization_screen.dart';
import '../../core/theme/motion.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late ConfettiController _confettiController;
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Check for pending progress celebrations.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForCelebration();
      // Donate intent for Siri to learn this pattern
      SiriService().donateStatsViewed();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _checkForCelebration() {
    final xpService = context.read<XPService>();
    final levelUp = xpService.pendingLevelUp;
    if (levelUp != null) {
      _showLevelUpCelebration(levelUp);
      return;
    }

    final achievements = context.read<AchievementsService>();
    final nextAchievement = achievements.popNewlyUnlocked();
    if (nextAchievement != null) {
      _showAchievementCelebration(nextAchievement);
    }
  }

  void _showLevelUpCelebration(LevelUpEvent levelUp) {
    if (!shouldReduceMotion(context)) _confettiController.play();
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LevelUpDialog(
        levelUp: levelUp,
        onDismiss: () {
          Navigator.of(ctx).pop();
          context.read<XPService>().clearPendingLevelUp();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _checkForCelebration();
          });
        },
        onSeeRewards: () {
          Navigator.of(ctx).pop();
          context.read<XPService>().clearPendingLevelUp();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PersonalizationScreen()),
          );
        },
      ),
    );
  }

  void _showAchievementCelebration(Achievement achievement) {
    if (!shouldReduceMotion(context)) _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AchievementUnlockedDialog(
        achievement: achievement,
        onDismiss: () {
          Navigator.of(ctx).pop();
          // Check for more achievements
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _checkForCelebration();
          });
        },
      ),
    );
  }

  void _showShareStatsCard(BuildContext context, StatsService stats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Your Progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Show off your Tiny Steps journey!',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            // Share card preview
            RepaintBoundary(
              key: _shareCardKey,
              child: StatsShareCard(
                tasksCompleted: stats.totalTasksCompleted,
                currentStreak: stats.currentStreak,
                totalSteps: stats.totalStepsCompleted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                // Capture before closing the sheet - the card is gone after.
                final bytes = await ShareService.capture(_shareCardKey);
                if (ctx.mounted) Navigator.pop(ctx);
                final shared = await ShareService.share(
                  imageBytes: bytes,
                  shareText:
                      'My Tiny Steps Progress: ${stats.currentStreak} day streak 🔥, ${stats.totalTasksCompleted} tasks completed! #TinySteps #ProductivityWin',
                  subject: 'My Tiny Steps Progress',
                );
                if (shared) stats.recordShare();
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>();
    final achievements = context.watch<AchievementsService>();
    final xpService = context.watch<XPService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Stats',
            onPressed: () => _showShareStatsCard(context, stats),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildLevelCard(context, xpService),
              const SizedBox(height: 24),
              _buildActivitySection(context, stats),
              const SizedBox(height: 24),
              _buildJourneySection(context, achievements, xpService),
              const SizedBox(height: 32),
            ],
          ),
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF4ECDC4),
                Color(0xFFFF6B6B),
                Color(0xFFFFBE76),
                Color(0xFF7BC47F),
                Color(0xFF9B59B6),
              ],
              numberOfParticles: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, XPService xpService) {
    final colorScheme = Theme.of(context).colorScheme;
    final xpRemaining =
        (xpService.xpForNextLevel - xpService.totalXP).clamp(0, 1000000);

    return Card(
      color: colorScheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${xpService.level}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEVEL ${xpService.level}',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${xpService.xpEarnedToday}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'XP today',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: xpService.progressToNextLevel,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$xpRemaining XP to Level ${xpService.level + 1}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${xpService.totalXP} XP total',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 300))
        .slideY(begin: -0.1, end: 0);
  }

  Widget _buildActivitySection(BuildContext context, StatsService stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'A compact view of your completed work.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActivityMetric(
                        icon: Icons.local_fire_department,
                        value: '${stats.currentStreak}',
                        label: 'Streak',
                      ),
                    ),
                    Expanded(
                      child: _ActivityMetric(
                        icon: Icons.task_alt,
                        value: '${stats.totalTasksCompleted}',
                        label: 'Tasks',
                      ),
                    ),
                    Expanded(
                      child: _ActivityMetric(
                        icon: Icons.checklist,
                        value: '${stats.totalStepsCompleted}',
                        label: 'Steps',
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _ActivityMetric(
                        icon: Icons.self_improvement,
                        value: _formatMinutes(stats.totalBodyDoubleMinutes),
                        label: 'Focus',
                      ),
                    ),
                    Expanded(
                      child: _ActivityMetric(
                        icon: Icons.timer_outlined,
                        value: '${stats.totalPomodoros}',
                        label: 'Pomodoros',
                      ),
                    ),
                    Expanded(
                      child: _ActivityMetric(
                        icon: Icons.hourglass_bottom,
                        value: '${stats.timerUsageCount}',
                        label: 'Timers',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildWeeklyChart(context, stats),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  Widget _buildWeeklyChart(BuildContext context, StatsService stats) {
    final last7Days = stats.getLast7DaysStats();
    final maxValue = last7Days.map((d) => d.tasksCompleted).fold<int>(0, max);
    final chartMax = maxValue > 0 ? maxValue : 1;
    final reduceMotion = shouldReduceMotion(context);
    // Leave room for the count and day labels as text scales up.
    final chartHeight = 72 + MediaQuery.textScalerOf(context).scale(48);

    return ExpansionTile(
      leading: const Icon(Icons.calendar_view_week_outlined),
      title: const Text('Weekly activity'),
      subtitle: const Text('Last 7 days'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: last7Days.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final heightFactor = day.tasksCompleted > 0
                    ? (day.tasksCompleted / chartMax).clamp(0.0, 1.0)
                    : 0.08;
                final isToday = index == last7Days.length - 1;
                final bar = FractionallySizedBox(
                  heightFactor: heightFactor,
                  widthFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );

                return Expanded(
                  child: Semantics(
                    label:
                        '${day.dayName}${isToday ? ', today' : ''}: ${day.tasksCompleted} ${day.tasksCompleted == 1 ? 'task' : 'tasks'} completed',
                    excludeSemantics: true,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.tasksCompleted > 0)
                          Text(
                            '${day.tasksCompleted}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: reduceMotion
                                ? bar
                                : bar
                                    .animate(
                                      delay: Duration(milliseconds: index * 80),
                                    )
                                    .scaleY(
                                      begin: 0,
                                      end: 1,
                                      alignment: Alignment.bottomCenter,
                                    )
                                    .fadeIn(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day.dayName,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: isToday ? FontWeight.bold : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: const Duration(milliseconds: 200))
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildJourneySection(
    BuildContext context,
    AchievementsService achievements,
    XPService xpService,
  ) {
    final nextAchievement = achievements.nextAchievement;
    final selectedTheme = UnlockableTheme.all.firstWhere(
      (theme) => theme.id == xpService.selectedTheme,
      orElse: () => UnlockableTheme.all.first,
    );
    final selectedSound = UnlockableSound.all.firstWhere(
      (sound) => sound.id == xpService.selectedSound,
      orElse: () => UnlockableSound.all.first,
    );
    final upcomingRewards = buildLevelRewards()
        .where((reward) => reward.level > xpService.level)
        .toList();
    final nextReward = upcomingRewards.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Up next', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Keep moving toward your next milestones.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (nextAchievement != null)
          _NextAchievementCard(
            achievement: nextAchievement,
            progress: achievements.progressFor(nextAchievement),
            progressLabel: achievements.progressLabelFor(nextAchievement),
            nextReward: nextReward,
          )
        else
          _AllAchievementsCompleteCard(nextReward: nextReward),
        const SizedBox(height: 24),
        Text('Explore', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Achievements'),
                subtitle: Text(
                  '${achievements.unlockedCount} of ${achievements.totalCount} unlocked',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AchievementsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('Level progression'),
                subtitle: const Text('See every level and unlock'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LevelProgressionScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Personalize'),
                subtitle: Text(
                  '${selectedTheme.name} · ${selectedSound.name}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PersonalizationScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextAchievementCard extends StatelessWidget {
  final Achievement achievement;
  final double progress;
  final String progressLabel;
  final LevelRewardInfo? nextReward;

  const _NextAchievementCard({
    required this.achievement,
    required this.progress,
    required this.progressLabel,
    this.nextReward,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Next achievement: ${achievement.title}. '
          '$progressLabel completed.'
          '${nextReward == null ? '' : ' Next level unlock: ${nextReward!.name} ${nextReward!.type.label} at Level ${nextReward!.level}.'}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      achievement.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next up',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          achievement.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          achievement.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  progressLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (nextReward != null) ...[
                const Divider(height: 32),
                _NextRewardRow(reward: nextReward!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AllAchievementsCompleteCard extends StatelessWidget {
  final LevelRewardInfo? nextReward;

  const _AllAchievementsCompleteCard({this.nextReward});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.emoji_events,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Collection complete'),
            subtitle: const Text('Every achievement is unlocked.'),
          ),
          if (nextReward != null) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _NextRewardRow(reward: nextReward!),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextRewardRow extends StatelessWidget {
  final LevelRewardInfo reward;

  const _NextRewardRow({required this.reward});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LevelProgressionScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(reward.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next level unlock',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${reward.name} ${reward.type.label.toLowerCase()}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'Reach Level ${reward.level}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ActivityMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AchievementUnlockedDialog extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onDismiss;

  const _AchievementUnlockedDialog({
    required this.achievement,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉',
              style: TextStyle(fontSize: 48),
            )
                .animate(
                  onPlay: (c) =>
                      shouldReduceMotion(context) ? c.stop() : c.repeat(),
                )
                .shake(hz: 2, duration: const Duration(milliseconds: 500))
                .then()
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
                .then()
                .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
            const SizedBox(height: 16),
            Text(
              'Achievement Unlocked!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    achievement.icon,
                    style: const TextStyle(fontSize: 48),
                  ).animate().scale(
                        begin: const Offset(0, 0),
                        end: const Offset(1, 1),
                        curve: Curves.elasticOut,
                        duration: const Duration(milliseconds: 800),
                      ),
                  const SizedBox(height: 12),
                  Text(
                    achievement.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    achievement.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 200))
                .slideY(begin: 0.3, end: 0),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onDismiss,
              child: const Text('Awesome!'),
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 200))
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }
}

class _LevelUpDialog extends StatelessWidget {
  final LevelUpEvent levelUp;
  final VoidCallback onDismiss;
  final VoidCallback onSeeRewards;

  const _LevelUpDialog({
    required this.levelUp,
    required this.onDismiss,
    required this.onSeeRewards,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Text(
        PlayerTitle.getTitleForLevel(levelUp.newLevel).emoji,
        style: const TextStyle(fontSize: 48),
      ),
      title: const Text('Level up!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You reached level ${levelUp.newLevel}.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (levelUp.hasUnlocks) ...[
            const SizedBox(height: 16),
            const Text('You unlocked new rewards!'),
          ],
        ],
      ),
      actions: [
        if (levelUp.hasUnlocks)
          TextButton(
            onPressed: onSeeRewards,
            child: const Text('See rewards'),
          ),
        FilledButton(
          onPressed: onDismiss,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
