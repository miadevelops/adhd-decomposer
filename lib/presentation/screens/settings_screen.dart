import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../../data/models/player_profile.dart';
import '../../data/services/calendar_service.dart';
import '../../data/services/xp_service.dart';
import 'paywall_screen.dart';
import 'feedback_screen.dart';
import 'coach_selector_screen.dart';
import 'debug_screen.dart';
import 'personalization_screen.dart';

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
                subtitle: 'Play sounds on task completion',
                value: provider.soundEnabled,
                onChanged: (value) => provider.setSoundEnabled(value),
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
              _buildSwitchTile(
                context,
                icon: Icons.music_note_outlined,
                title: 'Celebration Sounds',
                subtitle: 'Play sounds when completing tasks',
                value: provider.celebrationSoundEnabled,
                onChanged: (value) =>
                    provider.setCelebrationSoundEnabled(value),
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

              // Calendar integration hidden for v1 - see GitHub issue #5
              // const Divider(height: 32),
              // _buildSectionHeader(context, 'Calendar'),
              // _buildCalendarSettings(context),

              const Divider(height: 32),
              _buildSectionHeader(context, 'Personalization'),
              _buildRewardPersonalizationTile(context),
              _buildNameTile(context, provider),
              _buildCoachSelectorTile(context, provider),

              const Divider(height: 32),
              _buildSectionHeader(context, 'AI Decomposition'),
              _buildDecompositionStyleTile(context, provider),

              const Divider(height: 32),
              _buildSectionHeader(context, 'Body Double'),
              _buildDefaultAmbientSoundTile(context, provider),

              // BYOK hidden for v1 - see GitHub issue for v2 roadmap
              // const Divider(height: 32),
              // _buildSectionHeader(context, 'Power User'),
              // _buildApiKeyTile(context, provider),

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
                subtitle: const Text('Delete all tasks and progress'),
                onTap: () => _showClearConfirmation(context),
              ),

              const Divider(height: 32),
              _buildSectionHeader(context, 'About'),
              _buildUsageStats(context, provider),
              ListTile(
                leading: const Icon(Icons.info_outlined),
                title: const Text('Tiny Steps'),
                subtitle: const Text('Version 1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl(
                    'https://www.freeprivacypolicy.com/live/bece15e9-ea42-4925-a22b-9d0bae1bbfe3'),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Website'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl('https://tinysteps-6hy.pages.dev'),
              ),
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('Made for ADHD minds'),
                subtitle: const Text('One tiny step at a time'),
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
                      remaining == -1
                          ? 'Unlimited breakdowns with your API key'
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
                    child: ExcludeSemantics(
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
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
          title: const Text('Theme & celebration sound'),
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

  Widget _buildCalendarSettings(BuildContext context) {
    final calendarService = context.read<CalendarService>();

    return FutureBuilder<bool>(
      future: calendarService.hasCalendarPermission(),
      builder: (context, snapshot) {
        final hasPermission = snapshot.data ?? false;
        final isEnabled = calendarService.calendarEnabled;

        return Column(
          children: [
            SwitchListTile(
              secondary: Icon(
                isEnabled && hasPermission
                    ? Icons.calendar_today
                    : Icons.calendar_today_outlined,
                color: isEnabled && hasPermission
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text('Calendar Integration'),
              subtitle: Text(
                isEnabled && hasPermission
                    ? 'Block time for tasks in your calendar'
                    : 'Enable to schedule tasks as calendar events',
              ),
              value: isEnabled && hasPermission,
              onChanged: (value) async {
                if (value) {
                  final granted = await calendarService.enableCalendar();
                  if (!granted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please enable calendar access in system settings'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  calendarService.disableCalendar();
                }
                // Force rebuild
                if (context.mounted) {
                  (context as Element).markNeedsBuild();
                }
              },
            ),
            if (isEnabled && hasPermission) ...[
              _buildDefaultCalendarTile(context, calendarService),
              _buildReminderMinutesTile(context, calendarService),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDefaultCalendarTile(
      BuildContext context, CalendarService calendarService) {
    return FutureBuilder(
      future: calendarService.getAvailableCalendars(),
      builder: (context, snapshot) {
        final calendars = snapshot.data ?? [];
        final defaultId = calendarService.defaultCalendarId;
        final defaultCalendar = calendars.isNotEmpty
            ? calendars.firstWhere(
                (c) => c.id == defaultId,
                orElse: () => calendars.first,
              )
            : null;

        return ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Default Calendar'),
          subtitle: Text(defaultCalendar?.name ?? 'Select a calendar'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showCalendarPicker(context, calendarService, calendars),
        );
      },
    );
  }

  void _showCalendarPicker(BuildContext context,
      CalendarService calendarService, List<Calendar> calendars) {
    if (calendars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No writable calendars found'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Calendar'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: calendars.length,
            itemBuilder: (context, index) {
              final calendar = calendars[index];
              final isSelected =
                  calendar.id == calendarService.defaultCalendarId;

              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.calendar_today_outlined,
                  color:
                      isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(
                  calendar.name ?? 'Calendar',
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: calendar.accountName != null
                    ? Text(calendar.accountName!)
                    : null,
                onTap: () {
                  calendarService.defaultCalendarId = calendar.id;
                  Navigator.pop(ctx);
                  // Force rebuild
                  (context as Element).markNeedsBuild();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Calendar set to ${calendar.name}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderMinutesTile(
      BuildContext context, CalendarService calendarService) {
    final currentMinutes = calendarService.defaultReminderMinutes;

    return ListTile(
      leading: const Icon(Icons.alarm_outlined),
      title: const Text('Default Reminder'),
      subtitle: Text('$currentMinutes minutes before'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showReminderMinutesPicker(context, calendarService),
    );
  }

  void _showReminderMinutesPicker(
      BuildContext context, CalendarService calendarService) {
    final options = [5, 10, 15, 30];
    final currentMinutes = calendarService.defaultReminderMinutes;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reminder Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((mins) {
            final isSelected = mins == currentMinutes;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.access_time,
                color:
                    isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                '$mins minutes before',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () {
                calendarService.defaultReminderMinutes = mins;
                Navigator.pop(ctx);
                // Force rebuild
                (context as Element).markNeedsBuild();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reminder set to $mins minutes before'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
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

  void _showTimePicker(BuildContext context, TaskProvider provider) async {
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

  void _showNameDialog(BuildContext context, TaskProvider provider) {
    final controller = TextEditingController(text: provider.userName ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What should we call you?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Your name (optional)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            provider.setUserName(value.trim().isEmpty ? null : value.trim());
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              provider.setUserName(value.isEmpty ? null : value);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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

  Widget _buildApiKeyTile(BuildContext context, TaskProvider provider) {
    final hasKey = provider.hasCustomApiKey;

    return ListTile(
      leading: Icon(
        hasKey ? Icons.key : Icons.key_outlined,
        color: hasKey ? Colors.green : null,
      ),
      title: const Text('OpenAI API Key'),
      subtitle: Text(
        hasKey
            ? 'Custom key configured (unlimited use)'
            : 'Add your own key for unlimited breakdowns',
      ),
      trailing: hasKey
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _showRemoveApiKeyDialog(context, provider),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => _showApiKeyDialog(context, provider),
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
      statusColor = Colors.amber;
    } else {
      final remaining = provider.remainingFreeDecompositions;
      statusText = remaining > 0
          ? 'Free ($remaining breakdowns remaining)'
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

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Tasks?'),
        content: const Text(
          'This will permanently delete all your tasks and progress. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<TaskProvider>().clearAllTasks();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All tasks cleared'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, TaskProvider provider) {
    final controller = TextEditingController(text: provider.openAIApiKey ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OpenAI API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your OpenAI API key to unlock unlimited task decompositions. '
              'Your key is stored locally and never shared.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'sk-...',
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autocorrect: false,
            ),
            const SizedBox(height: 8),
            Text(
              'Get your key at platform.openai.com',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final key = controller.text.trim();
              if (key.isEmpty) {
                provider.setOpenAIApiKey(null);
              } else {
                provider.setOpenAIApiKey(key);
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(key.isEmpty ? 'API key removed' : 'API key saved'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRemoveApiKeyDialog(BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key?'),
        content: const Text(
          'This will remove your custom OpenAI API key. You\'ll be limited to free tier usage unless you upgrade to Pro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.setOpenAIApiKey(null);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('API key removed'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
