import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../../data/models/player_profile.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/xp_service.dart';
import 'paywall_screen.dart';
import 'feedback_screen.dart';
import 'coach_selector_screen.dart';
import 'debug_screen.dart';
import 'personalization_screen.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Premium status
              if (!provider.isPremium) _buildUpgradeBanner(context, provider),

              _buildSectionHeader(context, 'Notifications'),
              _buildNotificationToggle(context, provider),
              if (provider.notificationsEnabled) ...[
                _buildReminderTimeTile(context, provider),
                _buildSwitchTile(
                  context,
                  icon: Icons.notifications_active_outlined,
                  title: 'Gentle Nudge',
                  subtitle: 'Remind me 2 hours after I leave a task unfinished',
                  value: provider.gentleNudgeEnabled,
                  onChanged: (value) => provider.setGentleNudgeEnabled(value),
                ),
                _buildTestNotificationTile(context, provider),
              ],

              const Divider(height: 32),
              _buildSectionHeader(context, 'Feedback'),
              _buildSwitchTile(
                context,
                icon: Icons.volume_up_outlined,
                title: 'Sound Effects',
                subtitle: 'Step, timer and reminder sounds',
                value: provider.soundEnabled,
                onChanged: (value) => provider.setSoundEnabled(value),
              ),
              if (provider.soundEnabled)
                _buildSwitchTile(
                  context,
                  icon: Icons.music_note_outlined,
                  title: 'Celebration Sound',
                  subtitle: 'Play your celebration sound when a task is done',
                  value: provider.celebrationSoundEnabled,
                  onChanged: (value) =>
                      provider.setCelebrationSoundEnabled(value),
                ),
              _buildSwitchTile(
                context,
                icon: Icons.vibration_outlined,
                title: 'Haptic Feedback',
                subtitle: 'Vibrate on interactions',
                value: provider.hapticEnabled,
                onChanged: (value) => provider.setHapticEnabled(value),
              ),
              _buildSwitchTile(
                context,
                icon: Icons.celebration_outlined,
                title: 'Celebration Animation',
                subtitle: 'Show confetti on task completion',
                value: provider.confettiEnabled,
                onChanged: (value) => provider.setConfettiEnabled(value),
              ),

              const Divider(height: 32),
              _buildSectionHeader(context, 'Accessibility'),
              _buildSwitchTile(
                context,
                icon: Icons.animation_outlined,
                title: 'Reduce Animations',
                subtitle: 'Minimize motion for sensitive users',
                value: provider.reduceAnimations,
                onChanged: (value) => provider.setReduceAnimations(value),
              ),
              _buildSwitchTile(
                context,
                icon: Icons.skip_next_outlined,
                title: 'Auto-Advance Steps',
                subtitle: 'Automatically move to next step after completion',
                value: provider.autoAdvanceEnabled,
                onChanged: (value) => provider.setAutoAdvanceEnabled(value),
              ),

              const Divider(height: 32),
              _buildSectionHeader(context, 'Appearance'),
              _buildThemeSelector(context),
              _buildRewardPersonalizationTile(context),

              const Divider(height: 32),
              _buildSectionHeader(context, 'Personalization'),
              _buildNameTile(context, provider),
              _buildCoachSelectorTile(context, provider),

              const Divider(height: 32),
              _buildSectionHeader(context, 'AI Decomposition'),
              _buildDecompositionStyleTile(context, provider),

              const Divider(height: 32),
              _buildSectionHeader(context, 'Body Double'),
              _buildDefaultAmbientSoundTile(context, provider),

              const Divider(height: 32),
              _buildSectionHeader(context, 'Support'),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Send Feedback'),
                subtitle: const Text('Help us improve Tiny Steps'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                ),
              ),

              const Divider(height: 32),
              _buildSectionHeader(context, 'Data'),
              ListTile(
                leading: Icon(
                  Icons.delete_sweep_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Clear All Tasks'),
                subtitle: const Text('Delete all tasks (stats and streaks are kept)'),
                onTap: () => _showClearConfirmation(context),
              ),

              const Divider(height: 32),
              _buildSectionHeader(context, 'About'),
              _buildUsageStats(context, provider),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  return ListTile(
                    leading: const Icon(Icons.info_outlined),
                    title: const Text('Tiny Steps'),
                    subtitle: Text(
                      info == null
                          ? 'Version'
                          : 'Version ${info.version} (${info.buildNumber})',
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl(context, 
                    'https://www.freeprivacypolicy.com/live/bece15e9-ea42-4925-a22b-9d0bae1bbfe3'),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Website'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl(context, 'https://tinysteps-6hy.pages.dev'),
              ),
              const ListTile(
                leading: Icon(Icons.favorite_outline),
                title: Text('Made for ADHD minds'),
                subtitle: Text('One tiny step at a time'),
              ),

              // Debug tools — only in debug builds
              if (kDebugMode) ...[
                const Divider(height: 32),
                _buildSectionHeader(context, 'Developer'),
                ListTile(
                  leading: Icon(Icons.bug_report, color: Colors.red.shade700),
                  title: const Text('Debug Tools'),
                  subtitle:
                      const Text('Force onboarding, toggle premium, etc.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DebugScreen()),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildUpgradeBanner(BuildContext context, TaskProvider provider) {
    final remaining = provider.remainingFreeDecompositions;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Pro',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                    Text(
                      remaining <= 0
                          ? 'You\'ve used all your free breakdowns'
                          : remaining == 1
                              ? '1 free breakdown remaining'
                              : '$remaining free breakdowns remaining',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentPreference = themeProvider.preference;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ThemeProvider.getIcon(currentPreference),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'Choose your preferred appearance',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented control for theme selection
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: ThemePreference.values.map((pref) {
                final isSelected = pref == currentPreference;
                return Expanded(
                  child: Semantics(
                    label: '${ThemeProvider.getDisplayName(pref)} theme',
                    button: true,
                    selected: isSelected,
                    inMutuallyExclusiveGroup: true,
                    child: GestureDetector(
                        onTap: () {
                          themeProvider.setPreference(pref);
                          // Haptic feedback
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Theme set to ${ThemeProvider.getDisplayName(pref)}'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: ExcludeSemantics(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          constraints: const BoxConstraints(
                              minHeight: kMinInteractiveDimension),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                ThemeProvider.getIcon(pref),
                                size: 18,
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                ThemeProvider.getDisplayName(pref),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildRewardPersonalizationTile(BuildContext context) {
    return Consumer<XPService>(
      builder: (context, xpService, _) {
        final theme = UnlockableTheme.all.firstWhere(
          (theme) => theme.id == xpService.selectedTheme,
          orElse: () => UnlockableTheme.all.first,
        );
        final sound = UnlockableSound.all.firstWhere(
          (sound) => sound.id == xpService.selectedSound,
          orElse: () => UnlockableSound.all.first,
        );

        return ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Color scheme & celebration sound'),
          subtitle: Text('${theme.name} · ${sound.name}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PersonalizationScreen(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationToggle(BuildContext context, TaskProvider provider) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: const Text('Notifications'),
      subtitle: Text(
        provider.notificationsEnabled
            ? 'Receive gentle reminders'
            : 'Enable to get helpful reminders',
      ),
      value: provider.notificationsEnabled,
      onChanged: (value) async {
        if (value) {
          final enabled = await provider.enableNotifications();
          if (!enabled) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Please enable notifications in system settings'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else {
          await provider.disableNotifications();
        }
      },
    );
  }

  Widget _buildReminderTimeTile(BuildContext context, TaskProvider provider) {
    final hour = provider.reminderHour;
    final minute = provider.reminderMinute;
    final timeStr = TimeOfDay(hour: hour, minute: minute).format(context);

    return ListTile(
      leading: const Icon(Icons.access_time),
      title: const Text('Daily Reminder Time'),
      subtitle: Text('Remind me at $timeStr'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showTimePicker(context, provider),
    );
  }

  Future<void> _showTimePicker(BuildContext context, TaskProvider provider) async {
    final currentTime = TimeOfDay(
      hour: provider.reminderHour,
      minute: provider.reminderMinute,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      helpText: 'When should I remind you?',
    );

    if (picked != null) {
      await provider.setReminderTime(picked.hour, picked.minute);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder set for ${picked.format(context)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildTestNotificationTile(
      BuildContext context, TaskProvider provider) {
    return ListTile(
      leading: const Icon(Icons.send_outlined),
      title: const Text('Test Notification'),
      subtitle: const Text('Send a test notification now'),
      onTap: () async {
        await provider.showTestNotification();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test notification sent!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Widget _buildDecompositionStyleTile(
      BuildContext context, TaskProvider provider) {
    final style = provider.decompositionStyle;

    String styleName;
    String styleDesc;
    IconData styleIcon;

    switch (style) {
      case DecompositionStyle.quick:
        styleName = 'Quick';
        styleDesc = 'Fewer steps, faster completion';
        styleIcon = Icons.bolt;
        break;
      case DecompositionStyle.gentle:
        styleName = 'Gentle';
        styleDesc = 'Extra supportive for tough days';
        styleIcon = Icons.favorite_outline;
        break;
      case DecompositionStyle.standard:
        styleName = 'Standard';
        styleDesc = 'Balanced detail and support';
        styleIcon = Icons.auto_awesome_outlined;
        break;
    }

    return ListTile(
      leading: Icon(styleIcon),
      title: const Text('Decomposition Style'),
      subtitle: Text('$styleName - $styleDesc'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showDecompositionStyleDialog(context, provider),
    );
  }

  void _showDecompositionStyleDialog(
      BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decomposition Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose how tasks are broken down:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildStyleOption(
              context,
              provider,
              DecompositionStyle.standard,
              'Standard',
              'Balanced detail and encouragement',
              Icons.auto_awesome_outlined,
            ),
            _buildStyleOption(
              context,
              provider,
              DecompositionStyle.quick,
              'Quick',
              'Minimal steps for time pressure',
              Icons.bolt,
            ),
            _buildStyleOption(
              context,
              provider,
              DecompositionStyle.gentle,
              'Gentle',
              'Extra support for bad brain days',
              Icons.favorite_outline,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleOption(
    BuildContext context,
    TaskProvider provider,
    DecompositionStyle style,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = provider.decompositionStyle == style;

    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(description),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: () {
          provider.setDecompositionStyle(style);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Style changed to $title'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNameTile(BuildContext context, TaskProvider provider) {
    final name = provider.userName;

    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: const Text('Your Name'),
      subtitle: Text(name?.isNotEmpty == true ? name! : 'Not set'),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _showNameDialog(context, provider),
    );
  }

  Future<void> _showNameDialog(
      BuildContext context, TaskProvider provider) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initialName: provider.userName ?? ''),
    );
    if (result == null) return;
    provider.setUserName(result.isEmpty ? null : result);
  }

  Widget _buildCoachSelectorTile(BuildContext context, TaskProvider provider) {
    final coach = provider.selectedCoach;

    return ListTile(
      leading: Icon(
        coach.icon,
        size: 24,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Your Coach'),
      subtitle: Text('${coach.name} - ${coach.tagline}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CoachSelectorScreen()),
      ),
    );
  }

  Widget _buildDefaultAmbientSoundTile(
      BuildContext context, TaskProvider provider) {
    final sound = provider.defaultAmbientSound;

    String soundName;
    IconData soundIcon;

    switch (sound) {
      case DefaultAmbientSound.cafe:
        soundName = 'Café';
        soundIcon = Icons.coffee;
        break;
      case DefaultAmbientSound.rain:
        soundName = 'Rain';
        soundIcon = Icons.water_drop;
        break;
      case DefaultAmbientSound.whiteNoise:
        soundName = 'White Noise';
        soundIcon = Icons.waves;
        break;
      case DefaultAmbientSound.none:
        soundName = 'None';
        soundIcon = Icons.volume_off;
        break;
    }

    return ListTile(
      leading: Icon(soundIcon),
      title: const Text('Default Ambient Sound'),
      subtitle: Text('$soundName - plays when entering Body Double mode'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showDefaultAmbientSoundDialog(context, provider),
    );
  }

  void _showDefaultAmbientSoundDialog(
      BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Ambient Sound'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose the default sound for Body Double mode:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildSoundOption(
              context,
              provider,
              DefaultAmbientSound.none,
              'None',
              'Start in silence',
              Icons.volume_off,
            ),
            _buildSoundOption(
              context,
              provider,
              DefaultAmbientSound.cafe,
              'Café',
              'Ambient coffee shop sounds',
              Icons.coffee,
            ),
            _buildSoundOption(
              context,
              provider,
              DefaultAmbientSound.rain,
              'Rain',
              'Calming rain sounds',
              Icons.water_drop,
            ),
            _buildSoundOption(
              context,
              provider,
              DefaultAmbientSound.whiteNoise,
              'White Noise',
              'Consistent background noise',
              Icons.waves,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundOption(
    BuildContext context,
    TaskProvider provider,
    DefaultAmbientSound sound,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = provider.defaultAmbientSound == sound;

    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(description),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: () {
          provider.setDefaultAmbientSound(sound);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Default sound set to $title'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Widget _buildUsageStats(BuildContext context, TaskProvider provider) {
    final isPremium = provider.isPremium;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isPremium) {
      statusText = 'Pro (Unlimited)';
      statusIcon = Icons.workspace_premium;
      statusColor = StatusColors.of(context).warning;
    } else {
      final remaining = provider.remainingFreeDecompositions;
      statusText = remaining > 0
          ? 'Free ($remaining of ${SettingsService.freeDecompositionLimit} breakdowns remaining)'
          : 'Free (limit reached)';
      statusIcon = Icons.person_outline;
      statusColor = Theme.of(context).colorScheme.primary;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: const Text('Account Status'),
      subtitle: Text(statusText),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Couldn\'t open $url')),
      );
    }
  }

  void _showClearConfirmation(BuildContext context) {
    final provider = context.read<TaskProvider>();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Tasks?'),
        content: const Text(
          'This will delete all your tasks. Your stats and streaks are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final undo = provider.clearAllTasks();
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('All tasks cleared'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(label: 'Undo', onPressed: undo),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}

/// Owns its [TextEditingController] so it's disposed with the dialog.
class _NameDialog extends StatefulWidget {
  final String initialName;

  const _NameDialog({required this.initialName});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What should we call you?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Your name (optional)',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
