import 'dart:async';
import 'dart:math';
import 'package:clock/clock.dart';
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
import '../../data/services/backend_service.dart' show RateLimitException;
import '../../data/services/siri_service.dart';
import 'body_double_screen.dart';
import 'routines_screen.dart';
import 'paywall_screen.dart';
import '../../core/theme/motion.dart';
import '../widgets/scroll_fill.dart';
import '../../core/theme/app_theme.dart';

class ExecuteScreen extends StatefulWidget {
  /// Optional callback when task is completed (used for routines)
  final VoidCallback? onTaskComplete;

  const ExecuteScreen({super.key, this.onTaskComplete});

  @override
  State<ExecuteScreen> createState() => _ExecuteScreenState();
}

class _ExecuteScreenState extends State<ExecuteScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late ConfettiController _confettiController;
  final SoundService _soundService = SoundService();
  final GlobalKey _shareCardKey = GlobalKey();
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _timerRunning = false;
  int? _selectedMinutes;
  // Timers are driven by the wall clock so they stay accurate when the app
  // is backgrounded or a periodic tick is delayed.
  DateTime? _timerEndsAt;
  int _timerTotalSeconds = 0;
  // True while Body Double is open on top; its own timer and chimes take over.
  bool _isCovered = false;
  bool _showCelebration = false;
  String? _celebrationMessage;
  bool _hasTriggeredCompletion = false;
  String? _completionMessage;

  // Time blindness tracking
  Timer? _stepTimer;
  DateTime _stepStartedAt = clock.now();
  int _stepSecondsElapsed = 0;
  bool _hasShown5MinWarning = false;
  bool _hasShownEstimateWarning = false;
  bool _hasShownDoubleWarning = false;
  String? _timeBlindnessAlert;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    WidgetsBinding.instance.addObserver(this);

    // Start tracking time on this step
    _startStepTimer();

    // Donate intent when user continues a task
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SiriService().donateContinueTask();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    _timer?.cancel();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Periodic timers don't fire while backgrounded; catch up immediately.
    if (state == AppLifecycleState.resumed) {
      _onStepTick();
      _onFocusTimerTick();
    }
  }

  /// Start tracking elapsed time on current step (for time blindness alerts)
  void _startStepTimer() {
    _stepTimer?.cancel();
    _stepStartedAt = clock.now();
    _stepSecondsElapsed = 0;
    _hasShown5MinWarning = false;
    _hasShownEstimateWarning = false;
    _hasShownDoubleWarning = false;
    _timeBlindnessAlert = null;

    // The elapsed time isn't displayed, so no per-second rebuild is needed.
    _stepTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _onStepTick());
  }

  void _stopAllTimers() {
    _stepTimer?.cancel();
    _stepTimer = null;
    _timer?.cancel();
    _timer = null;
    _timerEndsAt = null;
    _timerRunning = false;
  }

  void _onStepTick() {
    if (!mounted || _stepTimer == null || _isCovered) return;
    _stepSecondsElapsed = clock.now().difference(_stepStartedAt).inSeconds;
    _checkTimeBlindnessAlerts();
  }

  /// Check and trigger time blindness alerts
  void _checkTimeBlindnessAlerts() {
    final provider = context.read<TaskProvider>();
    final step = provider.activeTask?.currentStep;
    if (step == null) return;

    final estimatedSeconds = step.estimatedMinutes * 60;
    final elapsedMinutes = _stepSecondsElapsed ~/ 60;

    // Alert 1: Timer has 5 minutes left (only if timer is running and was
    // set for longer than 5 minutes, otherwise it would fire immediately)
    if (_timerRunning &&
        _timerTotalSeconds > 300 &&
        _secondsRemaining > 0 &&
        _secondsRemaining <= 300 &&
        !_hasShown5MinWarning) {
      _hasShown5MinWarning = true;
      _showTimeAlert('5 minutes left', sticky: false);
    }

    // Alert 3 supersedes alert 2 if both thresholds were crossed at once
    // (e.g. returning to the app after a long time away).
    if (estimatedSeconds > 0 &&
        _stepSecondsElapsed >= estimatedSeconds * 2 &&
        !_hasShownDoubleWarning) {
      _hasShownEstimateWarning = true;
    }

    // Alert 2: You've been on this step longer than estimated
    if (_stepSecondsElapsed >= estimatedSeconds &&
        estimatedSeconds > 0 &&
        !_hasShownEstimateWarning) {
      _hasShownEstimateWarning = true;
      _showTimeAlert(
          '${step.estimatedMinutes} min on this step — no rush, just a heads up',
          sticky: false);
    }

    // Alert 3: Double the estimated time (gentle check-in) - STICKY
    if (_stepSecondsElapsed >= estimatedSeconds * 2 &&
        estimatedSeconds > 0 &&
        !_hasShownDoubleWarning) {
      _hasShownDoubleWarning = true;
      _showTimeAlert(
          '$elapsedMinutes min now — stuck? Tap "I\'m stuck" for smaller steps',
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
    });

    // Announce for screen readers
    SemanticsService.announce(message, TextDirection.ltr);

    // Auto-dismiss after 5 seconds (only for non-sticky alerts)
    if (!sticky) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _timeBlindnessAlert == message) {
          setState(() {
            _timeBlindnessAlert = null;
          });
        }
      });
    }
  }

  /// Check if animations should be reduced based on settings or system preferences
  bool _shouldReduceAnimations(BuildContext context) =>
      shouldReduceMotion(context);

  /// Check if confetti should be shown
  bool _shouldShowConfetti(BuildContext context) {
    final provider = context.read<TaskProvider>();
    return provider.confettiEnabled && !shouldReduceMotion(context);
  }

  @override
  Widget build(BuildContext context) {
    final task = context.watch<TaskProvider>().activeTask;
    final inProgress = task != null && !task.isCompleted;

    // System back / swipe while mid-task goes through the same confirmation
    // as the close button instead of silently leaving.
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirmation(context);
      },
      child: Scaffold(
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
          container: true,
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
                    semanticsLabel: 'Time alert: $_timeBlindnessAlert',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _timeBlindnessAlert = null;
                  }),
                  tooltip: 'Dismiss alert',
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    size: 20,
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
        child: ScrollFill(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with coach avatar and task info
            Row(
              children: [
                SizedBox(
                  width: kMinTouchTarget,
                  height: kMinTouchTarget,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _showExitConfirmation(context),
                    tooltip: 'Close task',
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
                SizedBox(
                  width: kMinTouchTarget,
                  height: kMinTouchTarget,
                  child: IconButton(
                    icon: const Icon(Icons.spa_outlined),
                    onPressed: () => _openBodyDouble(context),
                    tooltip: 'Body Double Mode',
                  ),
                ),
                // View full plan button
                SizedBox(
                  width: kMinTouchTarget,
                  height: kMinTouchTarget,
                  child: IconButton(
                    icon: const Icon(Icons.list_alt),
                    onPressed: () => _showTaskPlan(context, task),
                    tooltip: 'View Plan',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress with accessibility
            Semantics(
              label:
                  'Progress: ${(task.progress * 100).round()} percent complete. Step $stepNum of $totalSteps',
              excludeSemantics: true,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
            color: Colors.black.withValues(alpha: 0.1),
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

    // Keyed by step so each new step gets its own entrance animation.
    return card
        .animate(key: ValueKey(step.id))
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
        SizedBox(
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: kMinTouchTarget,
                child: OutlinedButton(
                  onPressed: () => _skipStep(provider),
                  child: const Text(AppStrings.skip),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                .map((mins) => SizedBox(
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

  Future<void> _openBodyDouble(BuildContext context) async {
    _isCovered = true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BodyDoubleScreen()),
    );
    if (!mounted) return;
    _isCovered = false;
    // Catch up on anything that elapsed while covered.
    _onStepTick();
    _onFocusTimerTick();
  }

  void _startTimer(int minutes) {
    _timer?.cancel();
    _hasShown5MinWarning = false;
    setState(() {
      _timerTotalSeconds = minutes * 60;
      _secondsRemaining = _timerTotalSeconds;
      _timerEndsAt = clock.now().add(Duration(seconds: _timerTotalSeconds));
      _timerRunning = true;
    });

    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => _onFocusTimerTick());
  }

  void _onFocusTimerTick() {
    if (!mounted || !_timerRunning || _timerEndsAt == null || _isCovered) {
      return;
    }

    final remainingMs = _timerEndsAt!.difference(clock.now()).inMilliseconds;
    final remaining = remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();

    if (remaining > 0) {
      if (remaining != _secondsRemaining) {
        setState(() => _secondsRemaining = remaining);
      }
      return;
    }

    _timer?.cancel();
    _timer = null;
    setState(() {
      _secondsRemaining = 0;
      _timerRunning = false;
      _timerEndsAt = null;
    });
    final provider = context.read<TaskProvider>();
    if (provider.hapticEnabled) {
      HapticFeedback.heavyImpact();
    }
    if (provider.soundEnabled) {
      _soundService.playTimerEnd();
    }
    // Announce timer completion for screen readers
    SemanticsService.announce('Timer complete', TextDirection.ltr);
  }

  void _toggleTimer() {
    if (_timerRunning) {
      // Pause: bring the remaining time up to date, then freeze it.
      _onFocusTimerTick();
      if (!_timerRunning) return; // Finished while catching up.
      _timer?.cancel();
      _timer = null;
      setState(() {
        _timerRunning = false;
        _timerEndsAt = null;
      });
    } else if (_secondsRemaining > 0) {
      setState(() {
        _timerEndsAt =
            clock.now().add(Duration(seconds: _secondsRemaining));
        _timerRunning = true;
      });
      _timer = Timer.periodic(
          const Duration(seconds: 1), (_) => _onFocusTimerTick());
    }
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
      setState(() {});
    } else {
      setState(() {
        _showCelebration = true;
        _celebrationMessage = message;
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          final advancedToNextStep = _completeCurrentStep(provider);
          if (advancedToNextStep) {
            _recordAndResetFocusTimer(provider);
          }
          _startStepTimer(); // Reset step timer for next step
          setState(() {
            _showCelebration = false;
          });
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
    if (_timerTotalSeconds > 0) {
      _onFocusTimerTick();
      final secondsUsed = _timerTotalSeconds - _secondsRemaining;
      final minutesUsed = (secondsUsed / 60).round();
      if (minutesUsed > 0) {
        provider.recordTimerUsage(minutesUsed);
      }
    }

    _timer?.cancel();
    _timer = null;
    _timerEndsAt = null;
    _timerTotalSeconds = 0;
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
    // Focus time spent before skipping is still real focus time.
    setState(() => _recordAndResetFocusTimer(provider));
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
        color: Colors.black.withValues(alpha: 0.3),
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
    final noProgress = task.endedWithoutProgress;
    // Picked once so the text doesn't change on every rebuild.
    _completionMessage ??= noProgress
        ? AppStrings.allStepsSkippedMessage
        : coach.getRandomCompletionMessage();

    // Play confetti on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Nothing left to time once the task has ended.
      _stopAllTimers();
      if (mounted && _timeBlindnessAlert != null) {
        setState(() => _timeBlindnessAlert = null);
      }
      if (!_hasTriggeredCompletion) {
        _hasTriggeredCompletion = true;

        if (noProgress) {
          SemanticsService.announce(
            '${AppStrings.allStepsSkippedTitle}. ${AppStrings.allStepsSkippedMessage}',
            TextDirection.ltr,
          );
          return;
        }

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
              label: noProgress
                  ? coach.name
                  : '${coach.name} celebrating with you',
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
                noProgress
                    ? AppStrings.allStepsSkippedTitle
                    : AppStrings.youDidIt,
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Use coach-specific completion message
            Text(
              _completionMessage!,
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
            if (!noProgress)
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
                  onPressed: () => _returnToTasks(context),
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

    // The rate prompt waits until the user leaves the celebration screen
    // (see _returnToTasks) so it never interrupts the moment.
    settings.incrementTasksSinceLastAsk();
  }

  void _returnToTasks(BuildContext context) {
    final settings = context.read<SettingsService>();
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    if (settings.shouldShowRatePrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted) {
          RateAppDialog.showIfNeeded(navigator.context, settings);
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
                    // Capture before closing the sheet - the card is gone after.
                    final bytes = await ShareService.capture(_shareCardKey);
                    if (ctx.mounted) Navigator.pop(ctx);
                    final shared = await ShareService.share(
                      imageBytes: bytes,
                      shareText:
                          'I just completed "${task.title}" using Tiny Steps! 🎉 #TinySteps #ProductivityWin',
                      subject: 'My Tiny Steps Achievement',
                    );
                    if (shared) statsService.recordShare();
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
                    _breakDownStep(step);
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

  Future<void> _breakDownStep(TaskStep step) async {
    final provider = context.read<TaskProvider>();

    // Show loading dialog. Back can't dismiss it, and we remove exactly this
    // route when done so we never pop the screen underneath by mistake.
    final navigator = Navigator.of(context, rootNavigator: true);
    final loadingRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
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
      },
    );
    navigator.push(loadingRoute);

    void closeLoadingDialog() {
      if (loadingRoute.isActive) navigator.removeRoute(loadingRoute);
    }

    try {
      // Call the provider to break down the current step
      final success = await provider.breakDownCurrentStep();
      closeLoadingDialog();

      if (mounted) {
        if (!success) {
          // User hit the free limit - show upgrade prompt
          _showBreakdownLimitDialog(context);
          return;
        }

        // The smaller pieces get their own fresh time estimates.
        setState(_startStepTimer);

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
      debugPrint('Step breakdown failed: $e');
      closeLoadingDialog();
      if (mounted) {
        final message = e is RateLimitException
            ? TaskProvider.friendlyError(e)
            : "Couldn't break this step down right now. Check your connection and try again.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (!mounted) return;
                final current = provider.activeTask?.currentStep;
                if (current != null && !current.hasSubSteps) {
                  _breakDownStep(current);
                }
              },
            ),
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
          'You\'ve used your ${SettingsService.freeDecompositionLimit} free breakdowns. '
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
