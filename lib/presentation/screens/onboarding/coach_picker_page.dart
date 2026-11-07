import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/motion.dart';
import '../../providers/task_provider.dart';

class CoachPickerPage extends StatefulWidget {
  final VoidCallback onNext;
  
  const CoachPickerPage({super.key, required this.onNext});

  @override
  State<CoachPickerPage> createState() => _CoachPickerPageState();
}

class _CoachPickerPageState extends State<CoachPickerPage> {
  late CoachType _selectedCoach;
  
  // Show all coaches – free ones selectable, premium ones shown locked
  final List<Coach> _allCoaches = Coaches.all;

  @override
  void initState() {
    super.initState();
    final current = context.read<TaskProvider>().selectedCoachType;
    _selectedCoach =
        Coaches.isFreeCoach(current) ? current : CoachType.default_;
  }

  void _selectCoach(Coach coach) {
    if (!Coaches.isFreeCoach(coach.type)) return;
    setState(() => _selectedCoach = coach.type);
    context.read<TaskProvider>().setSelectedCoach(coach.type);
  }

  void _showLockedCoach(Coach coach) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${coach.name} is a Pro coach. You can switch to it any time '
            'from Settings after upgrading.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          Text(
            'Pick your vibe',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn().slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 8),
          
          Text(
            'Different coaching styles for different moods',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 32),
          
          Expanded(
            child: ListView.builder(
              itemCount: _allCoaches.length,
              itemBuilder: (context, index) {
                final coach = _allCoaches[index];
                final isFree = Coaches.isFreeCoach(coach.type);
                final isSelected = _selectedCoach == coach.type;
                
                final card = Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CoachCard(
                    coach: coach,
                    isSelected: isSelected,
                    isLocked: !isFree,
                    onTap: isFree
                        ? () => _selectCoach(coach)
                        : () => _showLockedCoach(coach),
                  ),
                );
                if (shouldReduceMotion(context)) return card;
                return card
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 200 + index * 80))
                    .slideX(begin: 0.15, end: 0);
              },
            ),
          ),
          
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onNext,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final Coach coach;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback? onTap;
  
  const _CoachCard({
    required this.coach,
    required this.isSelected,
    this.isLocked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dimOpacity = isLocked ? 0.7 : 1.0;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isSelected,
        hint: isLocked ? 'Requires Pro' : null,
        child: Opacity(
      opacity: dimOpacity,
      child: Material(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Coach icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      coach.icon,
                      size: 28,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Coach info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coach.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coach.tagline,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
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
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PRO',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}
