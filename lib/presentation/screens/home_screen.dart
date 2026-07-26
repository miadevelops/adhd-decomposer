import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../../core/constants/strings.dart';
import '../../data/models/task.dart';
import '../../data/services/routine_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/xp_service.dart';
import 'decompose_screen.dart';
import 'execute_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'templates_screen.dart';
import 'routines_screen.dart';

/// Minimum touch target size for accessibility (48x48dp per WCAG guidelines)
const double kMinTouchTarget = 48.0;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = context.select<TaskProvider, String?>((provider) {
      final name = provider.userName?.trim();
      return name == null || name.isEmpty ? null : name;
    });

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/app_icon_1024.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  userName ?? AppStrings.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Level badge opens the combined profile and progress page.
          Consumer<XPService>(
            builder: (context, xpService, _) {
              return Semantics(
                label: 'Level ${xpService.level}. Tap to view progress',
                button: true,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StatsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lv ${xpService.level}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            value: xpService.progressToNextLevel,
                            strokeWidth: 2.5,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Semantics(
            label: 'View routines',
            button: true,
            excludeSemantics: true,
            child: IconButton(
              icon: const Icon(Icons.repeat_rounded),
              tooltip: 'Routines',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoutinesScreen()),
                );
              },
            ),
          ),
          Semantics(
            label: 'Open settings',
            button: true,
            excludeSemantics: true,
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer3<TaskProvider, RoutineService, SettingsService>(
        builder: (context, taskProvider, routineService, settings, _) {
          return _buildBody(context, taskProvider, routineService, settings);
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'Browse task templates',
            button: true,
            excludeSemantics: true,
            child: SizedBox(
              height: kMinTouchTarget,
              child: FloatingActionButton.extended(
                heroTag: 'templates',
                onPressed: () => _navigateToTemplates(context),
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('Templates'),
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: 'Create a new task',
            button: true,
            excludeSemantics: true,
            child: SizedBox(
              height: kMinTouchTarget,
              child: FloatingActionButton.extended(
                heroTag: 'new_task',
                onPressed: () => _navigateToDecompose(context),
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.newTask),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody(BuildContext context, TaskProvider taskProvider,
      RoutineService routineService, SettingsService settings) {
    final hasTasks = taskProvider.tasks.isNotEmpty;
    final hasRoutinesDue = routineService.hasRoutinesDue;
    final hasStreakCelebration = routineService.hasStreakCelebration;

    if (!hasTasks && !hasRoutinesDue) {
      return _buildEmptyState(context, routineService);
    }

    return _buildTaskList(context, taskProvider, routineService, settings,
        hasRoutinesDue, hasStreakCelebration);
  }

  Widget _buildEmptyState(BuildContext context, RoutineService routineService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show routines card if there are routines
            if (routineService.routines.isNotEmpty) ...[
              _RoutinesCard(routineService: routineService),
              const SizedBox(height: 32),
            ],
            Semantics(
              label:
                  'No tasks yet. Use the buttons below to create a new task or browse templates.',
              child: Column(
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    size: 80,
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    semanticLabel: 'Empty checklist',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.noTasksYet,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.startByAdding,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    TaskProvider provider,
    RoutineService routineService,
    SettingsService settings,
    bool hasRoutinesDue,
    bool hasStreakCelebration,
  ) {
    final activeTasks = provider.activeTasks;
    final completedTasks = provider.completedTasks;
    final showCompleted = settings.showCompletedTasks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Coach greeting card
        _CoachGreetingCard(),
        const SizedBox(height: 16),

        // Streak celebration banner
        if (hasStreakCelebration) _buildStreakBanner(context, routineService),

        // Routines due today section
        if (hasRoutinesDue) ...[
          _RoutinesDueTodaySection(routineService: routineService),
          const SizedBox(height: 24),
        ] else if (routineService.routines.isNotEmpty) ...[
          // Quick access to routines if they have some but none due
          _RoutinesQuickAccess(routineService: routineService),
          const SizedBox(height: 24),
        ],

        // Active tasks section
        if (activeTasks.isNotEmpty) ...[
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'In Progress',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          ...activeTasks.map((task) => _TaskCard(
                task: task,
                onTap: () => _startTask(context, task),
                onDelete: () => provider.deleteTask(task.id),
              )),
        ],

        // Completed tasks section
        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Completed (${completedTasks.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              Semantics(
                label: showCompleted
                    ? 'Hide completed tasks'
                    : 'Show completed tasks',
                button: true,
                child: TextButton.icon(
                  onPressed: () {
                    settings.showCompletedTasks = !showCompleted;
                  },
                  icon: Icon(
                    showCompleted
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(showCompleted ? 'Hide' : 'Show'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (showCompleted)
            ...completedTasks.map((task) => Opacity(
                  opacity: 0.7,
                  child: _TaskCard(
                    task: task,
                    onTap: null,
                    onDelete: () => provider.deleteTask(task.id),
                    isCompleted: true,
                  ),
                )),
        ],
      ],
    );
  }

  Widget _buildStreakBanner(
      BuildContext context, RoutineService routineService) {
    final streakRoutines = routineService.celebratoryStreaks;
    final longestStreak = streakRoutines.isNotEmpty
        ? streakRoutines
            .map((r) => r.completionStreak)
            .reduce((a, b) => a > b ? a : b)
        : 0;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoutinesScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$longestStreak day streak!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Keep your routines going!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDecompose(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DecomposeScreen()),
    );
  }

  void _navigateToTemplates(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TemplatesScreen()),
    );
  }

  void _startTask(BuildContext context, Task task) {
    context.read<TaskProvider>().setActiveTask(task);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExecuteScreen()),
    );
  }
}

/// Section showing routines due today with quick-start buttons
class _RoutinesDueTodaySection extends StatelessWidget {
  final RoutineService routineService;

  const _RoutinesDueTodaySection({required this.routineService});

  @override
  Widget build(BuildContext context) {
    final dueRoutines = routineService.routinesDueToday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  const Icon(
                    Icons.today,
                    size: 20,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Routines Due Today',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.orange,
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoutinesScreen()),
                );
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...dueRoutines.take(3).map((routine) => _RoutineDueCard(
              routine: routine,
              onStart: () => _startRoutine(context, routine),
            )),
        if (dueRoutines.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+${dueRoutines.length - 3} more routines',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ),
      ],
    );
  }

  void _startRoutine(BuildContext context, routine) {
    final task = routine.toTask();
    context.read<TaskProvider>().addTask(task);
    context.read<TaskProvider>().setActiveTask(task);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExecuteScreen(
          onTaskComplete: () {
            context.read<RoutineService>().markRoutineComplete(routine.id);
          },
        ),
      ),
    );
  }
}

/// Card for a routine that's due today
class _RoutineDueCard extends StatelessWidget {
  final dynamic routine;
  final VoidCallback onStart;

  const _RoutineDueCard({
    required this.routine,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.repeat,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Row(
                      children: [
                        Text(
                          '${routine.totalEstimatedMinutes} min · ${routine.steps.length} steps',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (routine.completionStreak > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '🔥 ${routine.completionStreak}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick access card when no routines are due
class _RoutinesQuickAccess extends StatelessWidget {
  final RoutineService routineService;

  const _RoutinesQuickAccess({required this.routineService});

  @override
  Widget build(BuildContext context) {
    final completedToday = routineService.routinesCompletedToday.length;
    final totalRoutines = routineService.routines.length;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoutinesScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All routines done!',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$completedToday of $totalRoutines completed today',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card showing routines summary (for empty state)
class _RoutinesCard extends StatelessWidget {
  final RoutineService routineService;

  const _RoutinesCard({required this.routineService});

  @override
  Widget build(BuildContext context) {
    final dueCount = routineService.routinesDueToday.length;
    final totalCount = routineService.routines.length;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoutinesScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.repeat_rounded,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Routines',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      dueCount > 0
                          ? '$dueCount due today'
                          : '$totalCount routines set up',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback onDelete;
  final bool isCompleted;

  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onDelete,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted;
    final progressPercent = (task.progress * 100).round();

    // Build semantic label for screen readers
    final semanticLabel = isCompleted
        ? 'Completed task: ${task.title}. ${task.completedStepsCount} steps done.'
        : 'Task: ${task.title}. ${task.completedStepsCount} of ${task.steps.length} steps completed. Estimated ${task.totalEstimatedMinutes} minutes. ${progressPercent > 0 ? '$progressPercent percent complete.' : ''} Double tap to continue.';

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          task.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isCompleted
                                        ? Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                        : null,
                                    height: 1.3, // Better line spacing
                                  ),
                        ),
                      ),
                    ),
                    if (isCompleted)
                      ExcludeSemantics(
                        child: Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          semanticLabel: 'Completed',
                        ),
                      )
                    else
                      Semantics(
                        label: 'Delete task ${task.title}',
                        button: true,
                        child: SizedBox(
                          width: kMinTouchTarget,
                          height: kMinTouchTarget,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: onDelete,
                            iconSize: 20,
                            tooltip: 'Delete task',
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${task.totalEstimatedMinutes} min',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.checklist,
                        size: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${task.completedStepsCount}/${task.steps.length} steps',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (!isCompleted && task.progress > 0) ...[
                  const SizedBox(height: 12),
                  ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: task.progress,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact card showing a greeting from the selected coach
class _CoachGreetingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        final coach = provider.selectedCoach;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Coach icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      coach.icon,
                      size: 24,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Greeting message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coach.name,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        coach.getRandomGreeting(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
