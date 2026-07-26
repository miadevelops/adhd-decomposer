import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../widgets/share_card.dart';
import '../widgets/rate_app_dialog.dart';
import '../../core/constants/strings.dart';
import '../../data/models/task.dart';
import '../../data/services/sound_service.dart';
import '../../data/services/share_service.dart';
import '../../data/services/stats_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/calendar_service.dart';
import '../../data/services/siri_service.dart';
import '../widgets/time_slot_picker.dart';
import 'body_double_screen.dart';
import 'routines_screen.dart';
import 'paywall_screen.dart';

/// Minimum touch target size for accessibility (48x48dp per WCAG guidelines)
const double kMinTouchTarget = 48.0;

class ExecuteScreen extends StatefulWidget {
  /// Optional callback when task is completed (used for routines)
  final VoidCallback? onTaskComplete;

  const ExecuteScreen({super.key, this.onTaskComplete});

  @override
  State<ExecuteScreen> createState() => _ExecuteScreenState();
}

class _ExecuteScreenState extends State<ExecuteScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  final SoundService _soundService = SoundService();
  final GlobalKey _shareCardKey = GlobalKey();
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _timerRunning = false;
  int? _selectedMinutes;
  bool _showCelebration = false;
  String? _celebrationMessage;
  bool _hasTriggeredCompletion = false;

  // Time blindness tracking
  Timer? _stepTimer;
  int _stepSecondsElapsed = 0;
  bool _hasShown5MinWarning = false;
  bool _hasShownEstimateWarning = false;
  bool _hasShownDoubleWarning = false;
  String? _timeBlindnessAlert;
  bool _isAlertSticky = false;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Start tracking time on this step
    _startStepTimer();

    // Donate intent when user continues a task
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SiriService().donateContinueTask();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _timer?.cancel();
    _stepTimer?.cancel();
    super.dispose();
  }

  /// Start tracking elapsed time on current step (for time blindness alerts)
  void _startStepTimer() {
    _stepTimer?.cancel();
    _stepSecondsElapsed = 0;
    _hasShown5MinWarning = false;
    _hasShownEstimateWarning = false;
    _hasShownDoubleWarning = false;
    _timeBlindnessAlert = null;
    _isAlertSticky = false;

    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _stepSecondsElapsed++;
        });
        _checkTimeBlindnessAlerts();
      }
    });
  }

  /// Check and trigger time blindness alerts
  void _checkTimeBlindnessAlerts() {
    final provider = context.read<TaskProvider>();
    final step = provider.activeTask?.currentStep;
    if (step == null) return;

    final estimatedSeconds = step.estimatedMinutes * 60;
    final elapsedMinutes = _stepSecondsElapsed ~/ 60;

    // Alert 1: Timer has 5 minutes left (only if timer is running)
    if (_timerRunning && _secondsRemaining == 300 && !_hasShown5MinWarning) {
      _hasShown5MinWarning = true;
      _showTimeAlert('5 minutes left', sticky: false);
    }

    // Alert 2: You've been on this step longer than estimated
    if (_stepSecondsElapsed == estimatedSeconds &&
        estimatedSeconds > 0 &&
        !_hasShownEstimateWarning) {
      _hasShownEstimateWarning = true;
      _showTimeAlert(
          '${step.estimatedMinutes} min on this step — no rush, just a heads up',
          sticky: false);
    }

    // Alert 3: Double the estimated time (gentle check-in) - STICKY
    if (_stepSecondsElapsed == estimatedSeconds * 2 &&
        estimatedSeconds > 0 &&
        !_hasShownDoubleWarning) {
      _hasShownDoubleWarning = true;
      _showTimeAlert(
          '${elapsedMinutes} min now — stuck? Tap "I\'m stuck" for smaller steps',
          sticky: true);
    }
  }

  /// Show a time blindness alert banner
  void _showTimeAlert(String message, {bool sticky = false}) {
    if (!mounted) return;

    final provider = context.read<TaskProvider>();

    // Play gentle sound
    if (provider.soundEnabled) {
      _soundService.playTimeWarning();
    }

    // Haptic feedback
    if (provider.hapticEnabled) {
      HapticFeedback.mediumImpact();
    }

    // Show alert banner
    setState(() {
      _timeBlindnessAlert = message;
      _isAlertSticky = sticky;
    });

    // Announce for screen readers
    SemanticsService.announce(message, TextDirection.ltr);

    // Auto-dismiss after 5 seconds (only for non-sticky alerts)
    if (!sticky) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _timeBlindnessAlert == message) {
          setState(() {
            _timeBlindnessAlert = null;
            _isAlertSticky = false;
          });
        }
      });
    }
  }

  /// Check if animations should be reduced based on settings or system preferences
  bool _shouldReduceAnimations(BuildContext context) {
    final provider = context.read<TaskProvider>();
    return provider.reduceAnimations;
  }

  /// Check if confetti should be shown
  bool _shouldShowConfetti(BuildContext context) {
    final provider = context.read<TaskProvider>();
    final reduceAnimations = provider.reduceAnimations;
    final shouldShow = provider.confettiEnabled && !reduceAnimations;
    return shouldShow;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Consumer<TaskProvider>(
            builder: (context, provider, _) {
              final task = provider.activeTask;
              if (task == null) {
                return Center(
                  child: Semantics(
                    label: 'No active task. Please go back and select a task.',
                    child: const Text('No active task'),
                  ),
                );
              }

              if (task.isCompleted) {
                return _buildCompletionScreen(context, task);
              }

              return _buildExecutionScreen(context, provider, task);
            },
          ),
          // Confetti overlay - always in tree, controller decides when to play
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
          // Celebration overlay
          if (_showCelebration) _buildCelebrationOverlay(context),
          // Time blindness alert banner
          if (_timeBlindnessAlert != null) _buildTimeBlindnessAlert(context),
        ],
      ),
    );
  }

  Widget _buildTimeBlindnessAlert(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Semantics(
          liveRegion: true,
          label: 'Time alert: $_timeBlindnessAlert',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _timeBlindnessAlert!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _timeBlindnessAlert = null;
                    _isAlertSticky = false;
                  }),
                  child: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutionScreen(
      BuildContext context, TaskProvider provider, Task task) {
    final step = task.currentStep!;
    final stepNum = task.currentStepIndex + 1;
    final totalSteps = task.steps.length;
    final reduceAnimations = _shouldReduceAnimations(context);
    final coach = provider.selectedCoach;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with coach avatar and task info
            Row(
              children: [
                Semantics(
                  label: 'Close task and return to home',
                  button: true,
                  excludeSemantics: true,
                  child: SizedBox(
                    width: kMinTouchTarget,
                    height: kMinTouchTarget,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _showExitConfirmation(context),
                      tooltip: 'Close task',
                    ),
                  ),
                ),
                // Coach icon
                Semantics(
                  label: '${coach.name} coaching you',
                  child: Icon(
                    coach.icon,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: 'Current task: ${task.title}',
                    header: true,
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Body Double mode button
                Semantics(
                  label: 'Open body double focus mode',
                  button: true,
                  excludeSemantics: true,
                  child: SizedBox(
                    width: kMinTouchTarget,
                    height: kMinTouchTarget,
                    child: IconButton(
                      icon: const Icon(Icons.spa_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BodyDoubleScreen(),
                        ),
                      ),
                      tooltip: 'Body Double Mode',
                    ),
                  ),
                ),
                // View full plan button
                Semantics(
                  label: 'View full task plan',
                  button: true,
                  excludeSemantics: true,
                  child: SizedBox(
                    width: kMinTouchTarget,
                    height: kMinTouchTarget,
                    child: IconButton(
                      icon: const Icon(Icons.list_alt),
                      onPressed: () => _showTaskPlan(context, task),
                      tooltip: 'View Plan',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress with accessibility
            Semantics(
              label:
                  'Progress: ${(task.progress * 100).round()} percent complete. Step $stepNum of $totalSteps',
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.step} $stepNum ${AppStrings.of_} $totalSteps',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Current step - big and prominent with semantics
            Semantics(
              label:
                  'Current step: ${step.action}. Estimated time: ${step.estimatedMinutes} minutes',
              liveRegion: true,
              child: _buildStepCard(context, step, reduceAnimations),
            ),

            const SizedBox(height: 24),

            // Timer section
            _buildTimerSection(context, step),

            const Spacer(),

            // Action buttons with proper touch targets and semantics
            _buildActionButtons(context, provider),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(
      BuildContext context, TaskStep step, bool reduceAnimations) {
    final card = Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // If step has substeps, show substep UI
          if (step.hasSubSteps) ...[
            // Parent step (smaller, context)
            Text(
              step.action,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Substep progress indicator
            _buildSubStepProgress(context, step),
            const SizedBox(height: 16),
            // Current substep (big)
            if (step.currentSubStep != null)
              Text(
                step.currentSubStep!.action,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      height: 1.3,
                    ),
                textAlign: TextAlign.left,
              )
            else
              Text(
                'All substeps done!',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  semanticLabel: 'Estimated time',
                ),
                const SizedBox(width: 8),
                Text(
                  '~${step.currentSubStep?.estimatedMinutes ?? step.estimatedMinutes} min',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ] else ...[
            // Normal step (no substeps)
            Text(
              step.action,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    height: 1.3, // Improved line spacing for dyslexia
                  ),
              textAlign: TextAlign.left, // Left-align for readability
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  semanticLabel: 'Estimated time',
                ),
                const SizedBox(width: 8),
                Text(
                  '~${step.estimatedMinutes} min',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ],
      ),
    );

    // Skip animations if reduced motion is preferred
    if (reduceAnimations) {
      return card;
    }

    return card
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 300))
        .slideY(
            begin: 0.1, end: 0, duration: const Duration(milliseconds: 300));
  }

  Widget _buildSubStepProgress(BuildContext context, TaskStep step) {
    final total = step.subSteps!.length;
    final current = step.currentSubStepIndex + 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < step.currentSubStepIndex
                  ? Theme.of(context).colorScheme.primary
                  : i == step.currentSubStepIndex
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.5)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
            ),
          ),
          if (i < total - 1) const SizedBox(width: 6),
        ],
        const SizedBox(width: 12),
        Text(
          'Substep $current of $total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, TaskProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main "Done" button with proper touch target
        Semantics(
          label: 'Mark step as done',
          button: true,
          excludeSemantics: true,
          hint: 'Double tap to complete this step',
          child: SizedBox(
            height: max(kMinTouchTarget, 56), // Ensure minimum touch target
            child: ElevatedButton(
              onPressed: () => _completeStep(provider),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                AppStrings.done,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Skip this step',
                button: true,
                excludeSemantics: true,
                hint: 'Double tap to skip to the next step',
                child: SizedBox(
                  height: kMinTouchTarget,
                  child: OutlinedButton(
                    onPressed: () => _skipStep(provider),
                    child: const Text(AppStrings.skip),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                label: "I'm stuck on this step",
                button: true,
                excludeSemantics: true,
                hint:
                    'Double tap for help breaking down this step into smaller parts',
                child: SizedBox(
                  height: kMinTouchTarget,
                  child: OutlinedButton(
                    // Disable if step already has substeps
                    onPressed: provider.activeTask!.currentStep!.hasSubSteps
                        ? null
                        : () => _showStuckDialog(
                            context, provider.activeTask!.currentStep!),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        provider.activeTask!.currentStep!.hasSubSteps
                            ? 'Already broken down'
                            : AppStrings.imStuck,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimerSection(BuildContext context, TaskStep step) {
    if (_timerRunning || _secondsRemaining > 0) {
      return _buildActiveTimer(context);
    }

    return _buildTimerOptions(context, step);
  }

  Widget _buildTimerOptions(BuildContext context, TaskStep step) {
    final options = [5, 10, 15, 25];

    return Semantics(
      label: 'Optional timer. Choose a duration to set a focus timer.',
      child: Column(
        children: [
          Text(
            'Optional timer',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((mins) => Semantics(
                      label: '$mins minute timer',
                      button: true,
                      excludeSemantics: true,
                      selected: _selectedMinutes == mins,
                      child: SizedBox(
                        height: kMinTouchTarget,
                        child: ChoiceChip(
                          label: Text('$mins min'),
                          selected: _selectedMinutes == mins,
                          onSelected: (selected) {
                            setState(() {
                              _selectedMinutes = selected ? mins : null;
                            });
                            if (selected) {
                              _startTimer(mins);
                            }
                          },
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTimer(BuildContext context) {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Semantics(
      label: 'Timer: $minutes minutes and $seconds seconds remaining',
      liveRegion: true,
      child: Column(
        children: [
          Text(
            timeString,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w300,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: _timerRunning ? 'Pause timer' : 'Resume timer',
            button: true,
            child: SizedBox(
              height: kMinTouchTarget,
              child: TextButton(
                onPressed: _toggleTimer,
                child:
                    Text(_timerRunning ? AppStrings.pause : AppStrings.resume),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startTimer(int minutes) {
    setState(() {
      _secondsRemaining = minutes * 60;
      _timerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0 && _timerRunning) {
        setState(() {
          _secondsRemaining--;
        });
      } else if (_secondsRemaining == 0) {
        timer.cancel();
        _timerRunning = false;
        HapticFeedback.heavyImpact();
        _soundService.playTimerEnd();
        // Announce timer completion for screen readers
        SemanticsService.announce('Timer complete', TextDirection.ltr);
      }
    });
  }

  void _toggleTimer() {
    setState(() {
      _timerRunning = !_timerRunning;
    });
  }

  void _completeStep(TaskProvider provider) {
    final reduceAnimations = _shouldReduceAnimations(context);

    if (provider.hapticEnabled) {
      HapticFeedback.mediumImpact();
    }

    if (_shouldShowConfetti(context)) {
      _confettiController.play();
    }

    if (provider.soundEnabled) {
      _soundService.playStepComplete();
    }

    // Use coach-specific completion message
    final coach = provider.selectedCoach;
    final message = coach.getRandomCompletionMessage();

    // Announce completion for screen readers
    SemanticsService.announce('Step completed! $message', TextDirection.ltr);

    // Check if auto-advance is enabled
    final autoAdvance = provider.autoAdvanceEnabled;

    if (reduceAnimations || !autoAdvance) {
      // Skip celebration overlay, advance immediately
      final advancedToNextStep = _completeCurrentStep(provider);
      if (advancedToNextStep) {
        _recordAndResetFocusTimer(provider);
      }
      _startStepTimer(); // Reset step timer for next step
    } else {
      setState(() {
        _showCelebration = true;
        _celebrationMessage = message;
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _showCelebration = false;
          });
          final advancedToNextStep = _completeCurrentStep(provider);
          if (advancedToNextStep) {
            _recordAndResetFocusTimer(provider);
          }
          _startStepTimer(); // Reset step timer for next step
        }
      });
    }
  }

  bool _completeCurrentStep(TaskProvider provider) {
    final task = provider.activeTask;
    final previousStepIndex = task?.currentStepIndex;
    provider.completeCurrentStep();
    return task == null || task.currentStepIndex != previousStepIndex;
  }

  void _recordAndResetFocusTimer(TaskProvider provider) {
    if (_selectedMinutes != null) {
      final minutesUsed = _selectedMinutes! - (_secondsRemaining ~/ 60);
      if (minutesUsed > 0) {
        provider.recordTimerUsage(minutesUsed);
      }
    }

    _timer?.cancel();
    _secondsRemaining = 0;
    _timerRunning = false;
    _selectedMinutes = null;
  }

  void _skipStep(TaskProvider provider) {
    if (provider.hapticEnabled) {
      HapticFeedback.lightImpact();
    }

    // Announce skip for screen readers
    SemanticsService.announce('Step skipped', TextDirection.ltr);

    provider.skipCurrentStep();
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 0;
      _timerRunning = false;
      _selectedMinutes = null;
    });
    _startStepTimer(); // Reset step timer for next step
  }

  Widget _buildCelebrationOverlay(BuildContext context) {
    final reduceAnimations = _shouldReduceAnimations(context);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        _celebrationMessage ?? 'Nice!',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );

    return Semantics(
      label: 'Celebration: ${_celebrationMessage ?? 'Nice!'}',
      liveRegion: true,
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: reduceAnimations
              ? content
              : content.animate().scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 200)),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen(BuildContext context, Task task) {
    final provider = context.read<TaskProvider>();
    final coach = provider.selectedCoach;

    // Play confetti on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasTriggeredCompletion) {
        _hasTriggeredCompletion = true;

        if (_shouldShowConfetti(context)) {
          _confettiController.play();
        }

        if (provider.hapticEnabled) {
          HapticFeedback.heavyImpact();
        }

        if (provider.soundEnabled) {
          _soundService.playTaskComplete(
            soundId: provider.selectedCelebrationSound,
          );
        }

        // Track task completion and check for rate prompt
        _onTaskCompleted(context, task);

        // Announce completion for screen readers
        SemanticsService.announce(
          'Congratulations! You completed ${task.title}. ${task.completedStepsCount} steps done.',
          TextDirection.ltr,
        );
      }
    });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Coach icon and celebration
            Semantics(
              label: '${coach.name} celebrating with you',
              child: Icon(
                coach.icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                AppStrings.youDidIt,
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Use coach-specific completion message
            Text(
              coach.getRandomCompletionMessage(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5, // Improved line spacing
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Semantics(
              label:
                  'Task summary: ${task.title}. ${task.completedStepsCount} steps completed, ${task.steps.where((s) => s.isSkipped).length} steps skipped.',
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          context,
                          '${task.completedStepsCount}',
                          'Steps Done',
                        ),
                        _buildStatItem(
                          context,
                          '${task.steps.where((s) => s.isSkipped).length}',
                          'Skipped',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Action buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Share button with proper touch target
                Expanded(
                  child: Semantics(
                    label: 'Share your achievement',
                    button: true,
                    child: SizedBox(
                      height: kMinTouchTarget,
                      child: OutlinedButton.icon(
                        onPressed: () => _showShareCard(context, task),
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),
                // Calendar scheduling hidden for v1 - see GitHub issue #5
              ],
            ),
            const SizedBox(height: 12),
            // Save as routine button
            Semantics(
              label: 'Save this task as a recurring routine',
              button: true,
              child: SizedBox(
                width: double.infinity,
                height: kMinTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: () => _saveAsRoutine(context, task),
                  icon: const Icon(Icons.repeat),
                  label: const Text('Save as Routine'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Return to task list',
              button: true,
              child: SizedBox(
                height: kMinTouchTarget,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(AppStrings.backToTasks),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTaskCompleted(BuildContext context, Task task) {
    final settings = context.read<SettingsService>();

    // Track analytics
    AnalyticsService.trackTaskCompleted(task);

    // Call the completion callback (used for routines)
    widget.onTaskComplete?.call();

    // Check for rate prompt
    settings.incrementTasksSinceLastAsk();

    // Small delay before showing rate dialog to not interrupt celebration
    if (settings.shouldShowRatePrompt) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          settings.recordRatePromptShown();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => RateAppDialog(settings: settings),
          );
        }
      });
    }
  }

  void _showShareCard(BuildContext context, Task task) {
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
            Semantics(
              header: true,
              child: Text(
                'Share Your Achievement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Show the world what you accomplished!',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            // Share card preview
            RepaintBoundary(
              key: _shareCardKey,
              child: CompletionShareCard(
                taskName: task.title,
                stepsCompleted: task.completedStepsCount,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: 'Share to social media',
              button: true,
              child: SizedBox(
                height: kMinTouchTarget,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final statsService = context.read<StatsService>();
                    Navigator.pop(ctx);
                    await ShareService.captureAndShare(
                      key: _shareCardKey,
                      shareText:
                          'I just completed "${task.title}" using Tiny Steps! 🎉 #TinySteps #ProductivityWin',
                      subject: 'My Tiny Steps Achievement',
                    );
                    // Track the share
                    statsService.recordShare();
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTimeSlotPicker(BuildContext context, Task task) {
    final calendarService = context.read<CalendarService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimeSlotPicker(
        task: task,
        calendarService: calendarService,
        onTimeSelected: (startTime) async {
          final eventId =
              await calendarService.createTimeBlock(task, startTime);
          if (mounted) {
            if (eventId != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('📅 Added to calendar!'),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Great!',
                    onPressed: () {},
                  ),
                ),
              );
              SemanticsService.announce(
                  'Task added to calendar', TextDirection.ltr);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Could not add to calendar. Check permissions.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        onQuickAdd: () async {
          Navigator.pop(ctx);
          final slot = await calendarService.findNextAvailableHour();
          if (slot != null) {
            final eventId =
                await calendarService.createTimeBlock(task, slot.start);
            if (mounted) {
              if (eventId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📅 Blocked ${slot.label}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  void _saveAsRoutine(BuildContext context, Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateRoutineScreen(taskToConvert: task),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Semantics(
      label: '$value $label',
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Semantics(
          header: true,
          child: const Text('Leave task?'),
        ),
        content: const Text("Your progress is saved. You can continue later."),
        actions: [
          Semantics(
            label: 'Stay and continue working on this task',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Stay'),
            ),
          ),
          Semantics(
            label: 'Leave and return to home screen',
            button: true,
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Leave'),
            ),
          ),
        ],
      ),
    );
  }

  void _showStuckDialog(BuildContext context, TaskStep step) {
    final provider = context.read<TaskProvider>();
    final coach = provider.selectedCoach;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coach icon
            Icon(
              coach.icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                "That's okay!",
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            // Use coach-specific stuck message
            Text(
              coach.getRandomStuckMessage(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Break it down further button - the key ADHD feature!
            Semantics(
              label: 'Break this step into smaller pieces',
              button: true,
              child: SizedBox(
                height: kMinTouchTarget,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _breakDownStep(context, step);
                  },
                  icon: const Icon(Icons.call_split),
                  label: const Text("Break it down smaller"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Quick mini-steps option
            Semantics(
              label: 'Show quick starter steps',
              button: true,
              child: SizedBox(
                height: kMinTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showQuickStarterSteps(context, step);
                  },
                  icon: const Icon(Icons.directions_walk),
                  label: const Text("Just help me start"),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Skip option
            Semantics(
              label: 'Skip this step for now',
              button: true,
              child: SizedBox(
                height: kMinTouchTarget,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _skipStep(provider);
                  },
                  child: const Text("Skip this one"),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTaskPlan(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Steps list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: task.steps.length,
                itemBuilder: (_, index) {
                  final step = task.steps[index];
                  final isCurrent = index == task.currentStepIndex;
                  final isCompleted = step.isCompleted;
                  final isSkipped = step.isSkipped;

                  return _buildPlanStepTile(
                    context,
                    step,
                    index,
                    isCurrent: isCurrent,
                    isCompleted: isCompleted,
                    isSkipped: isSkipped,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanStepTile(
    BuildContext context,
    TaskStep step,
    int index, {
    required bool isCurrent,
    required bool isCompleted,
    required bool isSkipped,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border:
            isCurrent ? Border.all(color: colorScheme.primary, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main step
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? colorScheme.primary
                        : isSkipped
                            ? colorScheme.outline
                            : isCurrent
                                ? colorScheme.primary.withValues(alpha: 0.2)
                                : colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check,
                            size: 16, color: colorScheme.onPrimary)
                        : isSkipped
                            ? Icon(Icons.skip_next,
                                size: 16, color: colorScheme.onInverseSurface)
                            : Text(
                                '${index + 1}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent
                                          ? colorScheme.primary
                                          : colorScheme.onSurface,
                                    ),
                              ),
                  ),
                ),
                const SizedBox(width: 12),
                // Step content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.action,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSkipped
                                  ? colorScheme.onSurface.withValues(alpha: 0.5)
                                  : isCurrent
                                      ? colorScheme.onPrimaryContainer
                                      : null,
                              decoration:
                                  isSkipped ? TextDecoration.lineThrough : null,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '~${step.estimatedMinutes} min',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isCurrent
                                  ? colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.7)
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NOW',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          // Substeps (if any)
          if (step.hasSubSteps) ...[
            Padding(
              padding: const EdgeInsets.only(left: 52, right: 12, bottom: 12),
              child: Column(
                children: step.subSteps!.asMap().entries.map((entry) {
                  final subIndex = entry.key;
                  final subStep = entry.value;
                  final isCurrentSub =
                      isCurrent && subIndex == step.currentSubStepIndex;
                  final isSubCompleted = subStep.isCompleted;

                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentSub
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentSub
                          ? Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Substep indicator
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSubCompleted
                                ? colorScheme.primary
                                : colorScheme.outline.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: isSubCompleted
                                ? Icon(Icons.check,
                                    size: 12, color: colorScheme.onPrimary)
                                : Text(
                                    '${subIndex + 1}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10,
                                        ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subStep.action,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: isCurrentSub
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                          ),
                        ),
                        Text(
                          '~${subStep.estimatedMinutes}m',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _breakDownStep(BuildContext context, TaskStep step) async {
    final provider = context.read<TaskProvider>();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Breaking it down...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );

    try {
      // Call the provider to break down the current step
      final success = await provider.breakDownCurrentStep();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (!success) {
          // User hit the free limit - show upgrade prompt
          _showBreakdownLimitDialog(context);
          return;
        }

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Step broken down into smaller pieces!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        SemanticsService.announce(
            'Step broken down into smaller pieces', TextDirection.ltr);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not break down step: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBreakdownLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Need more breakdowns?'),
        content: const Text(
          'You\'ve used your 5 free breakdowns. '
          'Upgrade to Pro for unlimited breakdowns and help whenever you\'re stuck!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
            child: const Text('See Pro'),
          ),
        ],
      ),
    );
  }

  void _showQuickStarterSteps(BuildContext context, TaskStep step) {
    final provider = context.read<TaskProvider>();
    final coach = provider.selectedCoach;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              coach.icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                "Let's just get moving",
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Quick starter steps',
              child: Column(
                children: [
                  _buildMiniStep(context, '1. Take a deep breath'),
                  _buildMiniStep(context, '2. Stand up and stretch'),
                  _buildMiniStep(context, '3. Walk to where you need to be'),
                  _buildMiniStep(
                      context, '4. Touch one thing related to the task'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: 'Close and try the task',
              button: true,
              child: SizedBox(
                height: kMinTouchTarget,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Okay, I'm moving!"),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStep(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
            child: Icon(
              Icons.arrow_forward,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: 'Step indicator',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.4, // Better line spacing
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
