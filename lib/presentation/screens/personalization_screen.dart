import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/player_profile.dart';
import '../../data/services/sound_service.dart';
import '../../data/services/xp_service.dart';
import 'level_progression_screen.dart';

class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final xpService = context.watch<XPService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Personalize')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('Level progression'),
              subtitle: const Text('See when every reward unlocks'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LevelProgressionScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'App theme',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a palette you have unlocked by leveling up.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...UnlockableTheme.all.map((theme) {
            final isUnlocked = xpService.isThemeUnlocked(theme.id);
            return _PersonalizationOption(
              emoji: isUnlocked ? theme.emoji : '🔒',
              title: theme.name,
              subtitle: isUnlocked
                  ? 'Unlocked at Level ${theme.requiredLevel}'
                  : 'Unlocks at Level ${theme.requiredLevel}',
              isUnlocked: isUnlocked,
              isSelected: xpService.selectedTheme == theme.id,
              onTap: isUnlocked ? () => xpService.selectTheme(theme.id) : null,
            );
          }),
          const SizedBox(height: 24),
          Text(
            'Celebration sound',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the sound used when you complete a task.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...UnlockableSound.all.map((sound) {
            final isUnlocked = xpService.isSoundUnlocked(sound.id);
            return _PersonalizationOption(
              emoji: isUnlocked ? sound.emoji : '🔒',
              title: sound.name,
              subtitle: isUnlocked
                  ? 'Tap to select and preview'
                  : 'Unlocks at Level ${sound.requiredLevel}',
              isUnlocked: isUnlocked,
              isSelected: xpService.selectedSound == sound.id,
              onTap: isUnlocked
                  ? () {
                      if (xpService.selectSound(sound.id)) {
                        SoundService().playTaskComplete(soundId: sound.id);
                      }
                    }
                  : null,
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PersonalizationOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isUnlocked;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PersonalizationOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isUnlocked,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? colorScheme.primary.withValues(alpha: 0.08) : null,
      child: ListTile(
        enabled: isUnlocked,
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isUnlocked
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: colorScheme.primary)
            : null,
      ),
    );
  }
}
