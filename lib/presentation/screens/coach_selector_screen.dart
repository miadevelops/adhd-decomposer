import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../../core/constants/strings.dart';
import '../../data/services/purchase_service.dart';
import 'paywall_screen.dart';
import '../../core/theme/app_theme.dart';

class CoachSelectorScreen extends StatelessWidget {
  const CoachSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.meetYourCoaches),
      ),
      body: Consumer2<TaskProvider, PurchaseService>(
        builder: (context, provider, purchases, _) {
          final isPremium = purchases.isPremium;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header explanation
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.chooseYourCoach,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.coachDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Coach cards
              ...Coaches.all.map((coach) {
                final isFree = Coaches.isFreeCoach(coach.type);
                final isLocked = !isPremium && !isFree;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CoachCard(
                    coach: coach,
                    isSelected: provider.selectedCoachType == coach.type,
                    isLocked: isLocked,
                    onSelect: () {
                      if (isLocked) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PaywallScreen()),
                        );
                        return;
                      }
                      provider.setSelectedCoach(coach.type);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(coach.icon, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${coach.name} is now your coach!')),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                );
              }),
              
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final Coach coach;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onSelect;
  
  const _CoachCard({
    required this.coach,
    required this.isSelected,
    required this.onSelect,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isSelected,
        hint: isLocked ? 'Requires Pro. Opens upgrade options.' : null,
        child: Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: isLocked ? 0.7 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        coach.icon,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Name and tagline
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                coach.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isLocked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.onTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PRO',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onTertiary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coach.tagline,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              
              // Sample messages
              Text(
                'Sample messages:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              
              // Completion message preview
              _MessagePreview(
                label: 'On completion:',
                message: coach.completionMessages.first,
                icon: Icons.check_circle_outline,
                color: StatusColors.of(context).success,
              ),
              const SizedBox(height: 8),
              
              // Stuck message preview  
              _MessagePreview(
                label: 'When stuck:',
                message: coach.stuckMessages.first,
                icon: Icons.help_outline,
                color: StatusColors.of(context).warning,
              ),
              const SizedBox(height: 8),
              
              // Greeting preview
              _MessagePreview(
                label: 'Greeting:',
                message: coach.greetings.first,
                icon: Icons.waving_hand_outlined,
                color: Theme.of(context).colorScheme.primary,
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

class _MessagePreview extends StatelessWidget {
  final String label;
  final String message;
  final IconData icon;
  final Color color;
  
  const _MessagePreview({
    required this.label,
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: '"$message"',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
