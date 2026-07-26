import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChallengePage extends StatelessWidget {
  final String? selectedChallenge;
  final ValueChanged<String> onChallengeSelected;
  
  const ChallengePage({
    super.key,
    required this.selectedChallenge,
    required this.onChallengeSelected,
  });
  
  static const challenges = [
    (
      id: 'overwhelm',
      title: 'Getting Overwhelmed',
      description: 'Tasks feel too big to start',
      icon: Icons.waves_outlined,
    ),
    (
      id: 'time_blindness',
      title: 'Time Blindness',
      description: 'Hard to estimate how long things take',
      icon: Icons.schedule_outlined,
    ),
    (
      id: 'starting',
      title: 'Starting Tasks',
      description: 'I know what to do but can\'t begin',
      icon: Icons.play_circle_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          Text(
            'What\'s your biggest\nchallenge?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          )
              .animate()
              .fadeIn()
              .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 8),
          
          Text(
            'This helps us personalize your experience',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms)
              .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 40),
          
          ...challenges.asMap().entries.map((entry) {
            final index = entry.key;
            final challenge = entry.value;
            final isSelected = selectedChallenge == challenge.id;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ChallengeCard(
                title: challenge.title,
                description: challenge.description,
                icon: challenge.icon,
                isSelected: isSelected,
                onTap: () => onChallengeSelected(challenge.id),
              ),
            )
                .animate()
                .fadeIn(delay: Duration(milliseconds: 200 + index * 100))
                .slideX(begin: 0.2, end: 0);
          }),
          
          const Spacer(),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _ChallengeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $description',
      button: true,
      selected: isSelected,
      child: ExcludeSemantics(
        child: Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
      ),
    ),
    );
  }
}
