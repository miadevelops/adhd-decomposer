import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/stats_service.dart';
import '../../data/services/purchase_service.dart';
import '../../data/services/xp_service.dart';
import '../providers/task_provider.dart';
import 'onboarding/onboarding_screen.dart';
import 'paywall_screen.dart';

/// Debug screen — only accessible in debug (kDebugMode) builds.
/// Provides quick toggles and actions for testing various app states.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  @override
  Widget build(BuildContext context) {
    // Safety: never render in release builds
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Not available')),
      );
    }

    final settings = context.read<SettingsService>();
    final stats = context.read<StatsService>();
    final purchases = context.watch<PurchaseService>();
    final xp = context.watch<XPService>();
    // Available if needed for future debug actions
    // final achievements = context.watch<AchievementsService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Tools'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildBanner(context),

          // ── Onboarding ──────────────────────────────────
          _sectionHeader(context, 'Onboarding'),
          _infoTile(
            icon: Icons.check_circle_outline,
            label: 'Onboarding complete',
            value: settings.onboardingComplete.toString(),
          ),
          _actionTile(
            icon: Icons.replay,
            label: 'Reset & show onboarding',
            subtitle: 'Sets onboardingComplete = false and opens onboarding',
            onTap: () {
              settings.onboardingComplete = false;
              // This screen is removed from the stack below, so capture the
              // navigator now instead of using this context later.
              final navigator = Navigator.of(context);
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(
                    onComplete: () => navigator.pop(),
                  ),
                ),
                (route) => route.isFirst,
              );
            },
          ),
          _actionTile(
            icon: Icons.slideshow,
            label: 'Preview onboarding (no reset)',
            subtitle: 'Shows onboarding without changing state',
            onTap: () {
              final navigator = Navigator.of(context);
              final wasComplete = settings.onboardingComplete;
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(
                    onComplete: () {
                      // OnboardingScreen marks itself complete; restore the
                      // previous value so this stays a preview.
                      settings.onboardingComplete = wasComplete;
                      navigator.pop();
                    },
                  ),
                ),
              );
            },
          ),

          const Divider(height: 32),

          // ── Premium / Purchases ─────────────────────────
          _sectionHeader(context, 'Premium & Purchases'),
          _infoTile(
            icon: Icons.workspace_premium,
            label: 'Premium (settings cache)',
            value: settings.isPremium.toString(),
          ),
          _infoTile(
            icon: Icons.store,
            label: 'PurchaseService.isPremium',
            value: purchases.isPremium.toString(),
          ),
          _infoTile(
            icon: Icons.shopping_bag_outlined,
            label: 'RevenueCat configured',
            value: purchases.isConfigured.toString(),
          ),
          _toggleTile(
            icon: Icons.toggle_on,
            label: 'Force premium ON (debug)',
            subtitle: 'Overrides the entitlement for this debug session',
            value: purchases.isPremium,
            onChanged: (v) {
              purchases.setDebugPremiumOverride(v);
              context.read<TaskProvider>().setPurchaseService(purchases);
              setState(() {});
              _snack(context, 'Premium ${v ? "enabled" : "disabled"} for this session');
            },
          ),
          _actionTile(
            icon: Icons.credit_card,
            label: 'Show paywall screen',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
          ),

          const Divider(height: 32),

          // ── Decomposition limits ────────────────────────
          _sectionHeader(context, 'Decomposition Limits'),
          _infoTile(
            icon: Icons.broken_image_outlined,
            label: 'Decomposition count',
            value: '${settings.decompositionCount} / ${SettingsService.freeDecompositionLimit}',
          ),
          _infoTile(
            icon: Icons.lock_open,
            label: 'Can decompose',
            value: settings.canDecompose.toString(),
          ),
          _actionTile(
            icon: Icons.restart_alt,
            label: 'Reset decomposition count',
            subtitle: 'Sets count back to 0',
            onTap: () {
              settings.decompositionCount = 0;
              setState(() {});
              _snack(context, 'Decomposition count reset to 0');
            },
          ),
          _actionTile(
            icon: Icons.speed,
            label: 'Max out decomposition count',
            subtitle: 'Triggers free-limit-reached state',
            onTap: () {
              settings.decompositionCount = SettingsService.freeDecompositionLimit;
              setState(() {});
              _snack(context, 'Decomposition count set to limit');
            },
          ),

          const Divider(height: 32),

          // ── XP & Level ──────────────────────────────────
          _sectionHeader(context, 'XP & Leveling'),
          _infoTile(
            icon: Icons.star,
            label: 'Current level',
            value: xp.level.toString(),
          ),
          _infoTile(
            icon: Icons.flash_on,
            label: 'Current XP / Next level',
            value: '${xp.currentXP} / ${xp.xpForNextLevel}',
          ),
          _infoTile(
            icon: Icons.all_inclusive,
            label: 'Total XP',
            value: xp.totalXP.toString(),
          ),
          _actionTile(
            icon: Icons.add_circle_outline,
            label: 'Award step-complete XP',
            subtitle: 'Grants step completion XP',
            onTap: () {
              final reward = xp.awardStepComplete();
              _snack(context, '+${reward.amount} XP (step complete)');
            },
          ),
          _actionTile(
            icon: Icons.exposure_plus_2,
            label: 'Award task-complete XP',
            subtitle: 'Grants task completion XP (may trigger level-up)',
            onTap: () {
              final rewards = xp.awardTaskComplete();
              final total = rewards.fold<int>(0, (sum, r) => sum + r.amount);
              _snack(context, '+$total XP (task complete, ${rewards.length} rewards)');
            },
          ),

          const Divider(height: 32),

          // ── Stats ───────────────────────────────────────
          _sectionHeader(context, 'Stats'),
          _infoTile(
            icon: Icons.task_alt,
            label: 'Tasks completed',
            value: stats.totalTasksCompleted.toString(),
          ),
          _infoTile(
            icon: Icons.checklist,
            label: 'Steps completed',
            value: stats.totalStepsCompleted.toString(),
          ),
          _infoTile(
            icon: Icons.local_fire_department,
            label: 'Current streak',
            value: stats.currentStreak.toString(),
          ),
          _infoTile(
            icon: Icons.emoji_events,
            label: 'Longest streak',
            value: stats.longestStreak.toString(),
          ),
          _actionTile(
            icon: Icons.local_fire_department,
            label: 'Set streak to 7',
            onTap: () {
              final now = DateTime.now();
              stats.currentStreak = 7;
              stats.lastCompletionDate =
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              setState(() {});
              _snack(context, 'Streak set to 7');
            },
          ),

          const Divider(height: 32),

          // ── User Identity ───────────────────────────────
          _sectionHeader(context, 'User Identity'),
          _infoTile(
            icon: Icons.person,
            label: 'User name',
            value: settings.userName ?? '(not set)',
          ),
          _infoTile(
            icon: Icons.psychology,
            label: 'User challenge',
            value: settings.userChallenge ?? '(not set)',
          ),
          _infoTile(
            icon: Icons.smart_toy,
            label: 'Selected coach',
            value: settings.selectedCoach.name,
          ),
          _actionTile(
            icon: Icons.person_remove,
            label: 'Clear user name & challenge',
            onTap: () {
              settings.userName = null;
              settings.userChallenge = null;
              setState(() {});
              _snack(context, 'User name & challenge cleared');
            },
          ),

          const Divider(height: 32),

          // ── Rate App ────────────────────────────────────
          _sectionHeader(context, 'Rate App Prompt'),
          _infoTile(
            icon: Icons.rate_review,
            label: 'Has rated',
            value: settings.hasRated.toString(),
          ),
          _infoTile(
            icon: Icons.question_answer,
            label: 'Times asked / max',
            value: '${settings.rateAskedCount} / ${SettingsService.maxAskCount}',
          ),
          _infoTile(
            icon: Icons.task,
            label: 'Tasks since last ask',
            value: settings.tasksSinceLastAsk.toString(),
          ),
          _actionTile(
            icon: Icons.restart_alt,
            label: 'Reset rate-app state',
            subtitle: 'Clears hasRated, ask count, tasks since last ask',
            onTap: () {
              settings.hasRated = false;
              settings.rateAskedCount = 0;
              settings.tasksSinceLastAsk = 0;
              setState(() {});
              _snack(context, 'Rate-app state reset');
            },
          ),

          const Divider(height: 32),

          // ── Danger zone ─────────────────────────────────
          _sectionHeader(context, 'Danger Zone'),
          _actionTile(
            icon: Icons.delete_forever,
            label: 'Clear all tasks',
            subtitle: 'Deletes all tasks from TaskProvider',
            color: Colors.red,
            onTap: () => _confirmAction(
              context,
              title: 'Clear all tasks?',
              message: 'This will delete every task.',
              onConfirm: () {
                context.read<TaskProvider>().clearAllTasks();
                _snack(context, 'All tasks cleared');
              },
            ),
          ),
          _actionTile(
            icon: Icons.warning_amber,
            label: 'Full factory reset',
            subtitle: 'Clears tasks, core stats, premium flag & onboarding state',
            color: Colors.red,
            onTap: () => _confirmAction(
              context,
              title: 'Factory reset?',
              message: 'This clears tasks, task/step counts, current streak, premium flag, '
                  'decomposition count, name, rating state and onboarding. Routines, XP, '
                  'achievements and other preferences are kept. You will see onboarding '
                  'again on next launch.',
              onConfirm: () async {
                settings.onboardingComplete = false;
                settings.isPremium = false;
                settings.decompositionCount = 0;
                settings.userName = null;
                settings.userChallenge = null;
                settings.hasRated = false;
                settings.rateAskedCount = 0;
                settings.tasksSinceLastAsk = 0;
                context.read<TaskProvider>().clearAllTasks();
                stats.totalTasksCompleted = 0;
                stats.totalStepsCompleted = 0;
                stats.currentStreak = 0;
                if (context.mounted) {
                  _snack(context, 'Factory reset complete — restart the app');
                }
              },
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _buildBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Debug-only tools. This page is hidden in release builds.',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
              setState(() {});
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
