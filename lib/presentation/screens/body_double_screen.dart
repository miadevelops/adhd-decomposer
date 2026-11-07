import 'dart:async';
import 'dart:math';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../../data/services/ambient_audio_service.dart';
import '../../data/services/sound_service.dart';
import '../../data/services/purchase_service.dart';
import 'paywall_screen.dart';
import '../../core/theme/motion.dart';

/// Body Double Mode - Digital presence for focus and accountability
/// 
/// Body doubling is when someone with ADHD works alongside another person.
/// This creates a calming digital companion for focus sessions.
class BodyDoubleScreen extends StatefulWidget {
  const BodyDoubleScreen({super.key});

  @override
  State<BodyDoubleScreen> createState() => _BodyDoubleScreenState();
}

class _BodyDoubleScreenState extends State<BodyDoubleScreen>
    with TickerProviderStateMixin {
  TaskProvider? _taskProvider;

  // Audio
  final AmbientAudioService _ambientAudio = AmbientAudioService();
  final SoundService _soundService = SoundService();
  
  // Timer - Pomodoro style
  Timer? _timer;
  int _secondsRemaining = 25 * 60; // 25 minutes default
  bool _isWorkSession = true;
  bool _timerRunning = false;
  // Wall-clock end time so the countdown stays accurate in the background.
  DateTime? _timerEndsAt;
  bool _showBreakPrompt = false;
  
  // Session tracking
  DateTime? _sessionStart;
  int _completedPomodoros = 0;
  
  // Encouragement messages
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _particleController;
  
  // Particles
  final List<_FloatingParticle> _particles = [];
  final Random _random = Random();
  
  // UI state - controls visibility
  bool _showControls = true;
  bool _isExiting = false;
  Timer? _hideControlsTimer;
  double _verticalDragDistance = 0.0;
  
  static const List<String> _encouragements = [
    "You're doing great. Keep going.",
    "One step at a time.",
    "I'm right here with you.",
    "Just focus on this one thing.",
    "No rush. Steady progress.",
    "You've got this.",
    "Breathe. You're making progress.",
    "Every small step counts.",
  ];

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    
    // Wakelock disabled for v1 — screen stays awake via system settings if needed
    
    // Hide status bar for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Pulse animation for presence indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    // Particle animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();
    
    // Initialize particles
    _initParticles();
    
    // Cycle encouragement messages every 30 seconds
    _messageTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _encouragements.length;
        });
      }
    });
    
    // Initialize audio
    _ambientAudio.initialize();
    
    // Load default ambient sound from settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultAmbientSound();
      _startHideControlsTimer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _taskProvider ??= context.read<TaskProvider>();
    _syncMotion();
  }

  /// Stops the ambient animations entirely (not just hides them) when the
  /// user or OS asks for reduced motion, so they don't tick every frame.
  void _syncMotion() {
    final reduce = shouldReduceMotion(context);
    if (reduce) {
      _pulseController.stop();
      _particleController.stop();
    } else {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
      if (!_particleController.isAnimating) _particleController.repeat();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _particles.clear();
    _initParticles();
  }
  
  void _loadDefaultAmbientSound() {
    final provider = context.read<TaskProvider>();
    final defaultSound = provider.defaultAmbientSound;
    
    // Convert DefaultAmbientSound to AmbientSound
    AmbientSound sound;
    switch (defaultSound) {
      case DefaultAmbientSound.cafe:
        sound = AmbientSound.cafe;
        break;
      case DefaultAmbientSound.rain:
        sound = AmbientSound.rain;
        break;
      case DefaultAmbientSound.whiteNoise:
        sound = AmbientSound.whiteNoise;
        break;
      case DefaultAmbientSound.none:
        sound = AmbientSound.none;
        break;
    }
    
    if (sound != AmbientSound.none) {
      _selectSound(sound);
    }
  }

  void _initParticles() {
    for (int i = 0; i < 15; i++) {
      _particles.add(_FloatingParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 2,
        driftCycles: 1 + _random.nextInt(2),
        opacity: _random.nextDouble() * 0.3 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    // Record session time in stats
    if (_sessionStart != null) {
      final sessionMinutes = DateTime.now().difference(_sessionStart!).inMinutes;
      if (sessionMinutes > 0) {
        _taskProvider?.recordBodyDoubleMinutes(sessionMinutes);
      }
    }
    
    _timer?.cancel();
    _messageTimer?.cancel();
    _hideControlsTimer?.cancel();
    _pulseController.dispose();
    _particleController.dispose();
    _ambientAudio.stop();
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    // Allow screen to sleep again
    // Screen can sleep again
    
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_showBreakPrompt) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTapAnywhere() {
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  Future<void> _exitScreen() async {
    if (_isExiting) return;
    _isExiting = true;
    _timer?.cancel();
    _messageTimer?.cancel();
    _hideControlsTimer?.cancel();
    await _ambientAudio.stop();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Swipe-down and back gestures are easy to trigger by accident, so ask
  /// first while a focus timer is running.
  Future<void> _requestExit() async {
    if (_isExiting) return;
    if (_timerRunning && _isWorkSession) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Leave focus session?'),
          content: const Text(
              "Your timer is still running. This session won't count if you leave now."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep going'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    await _exitScreen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Dark/muted color scheme for focus
    final backgroundColor = isDark 
        ? const Color(0xFF1a1a2e) 
        : const Color(0xFF2d2d44);
    
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _onTapAnywhere,
      onVerticalDragStart: (_) {
        _verticalDragDistance = 0.0;
      },
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 0) {
          _verticalDragDistance += details.delta.dy;
        }
      },
      onVerticalDragEnd: (details) {
        final isFastSwipe = (details.primaryVelocity ?? 0) > 300;
        final isLongDrag = _verticalDragDistance > 80;
        if (isFastSwipe || isLongDrag) {
          _requestExit();
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          // Reduce SafeArea bottom padding since we handle it ourselves
          bottom: false,
          child: Stack(
            children: [
              // Floating particles background
              _buildParticles(context),
              
              // Main content - always visible
              LayoutBuilder(
                builder: (context, constraints) {
                  // Compact mode thresholds - be aggressive to avoid overflow
                  final isCompact = constraints.maxHeight < 850;
                  final isVeryCompact = constraints.maxHeight < 700;
                  final contentPadding = isVeryCompact ? 8.0 : (isCompact ? 12.0 : 24.0);
                  final avatarSize = isVeryCompact ? 64.0 : (isCompact ? 80.0 : 120.0);
                  final innerAvatarSize = isVeryCompact ? 40.0 : (isCompact ? 52.0 : 80.0);
                  final messageFontSize = isVeryCompact ? 14.0 : (isCompact ? 15.0 : 18.0);
                  final messageHeight = isVeryCompact ? 32.0 : (isCompact ? 40.0 : 60.0);
                  final sectionGap = isVeryCompact ? 8.0 : (isCompact ? 12.0 : 32.0);
                  final timerRingSize = isVeryCompact ? 90.0 : (isCompact ? 110.0 : 160.0);
                  final timeFontSize = isVeryCompact ? 28.0 : (isCompact ? 36.0 : 48.0);

                  return Padding(
                    padding: EdgeInsets.all(contentPadding),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: [
                        // Header with controls (animated visibility)
                        AnimatedOpacity(
                          opacity: _showControls ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          // Hidden buttons shouldn't be tappable by accident.
                          child: IgnorePointer(
                            ignoring: !_showControls,
                            child: _buildHeader(context),
                          ),
                        ),

                        SizedBox(height: isVeryCompact ? 2 : (isCompact ? 6 : 24)),

                        // Avatar with pulse - always visible
                        _buildAvatar(
                          context,
                          outerSize: avatarSize,
                          innerSize: innerAvatarSize,
                        ),

                        SizedBox(height: isVeryCompact ? 2 : (isCompact ? 6 : 16)),

                        // Encouragement message - always visible
                        _buildEncouragementMessage(
                          context,
                          fontSize: messageFontSize,
                          height: messageHeight,
                        ),

                        SizedBox(height: sectionGap),

                        // Current step (if active) - constrained height
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: isVeryCompact ? 50 : (isCompact ? 64 : 100),
                          ),
                          child: _buildCurrentStep(
                            context,
                            padding: EdgeInsets.symmetric(
                              horizontal: isVeryCompact ? 10 : (isCompact ? 12 : 20),
                              vertical: isVeryCompact ? 6 : (isCompact ? 8 : 16),
                            ),
                            bodyFontSize: isVeryCompact ? 12 : (isCompact ? 13 : 16),
                          ),
                        ),

                        SizedBox(height: sectionGap),

                        // Timer - animated visibility
                        AnimatedOpacity(
                          opacity: _showControls ? 1.0 : 0.3,
                          duration: const Duration(milliseconds: 200),
                          child: _buildTimer(
                            context,
                            ringSize: timerRingSize,
                            timeFontSize: timeFontSize,
                            compact: isCompact || isVeryCompact,
                          ),
                        ),

                        SizedBox(height: isVeryCompact ? 4 : (isCompact ? 8 : 24)),

                        // Audio controls - animated visibility
                        AnimatedOpacity(
                          opacity: _showControls ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: IgnorePointer(
                            ignoring: !_showControls,
                            child: _buildAudioControls(
                              context,
                              compact: isCompact || isVeryCompact,
                            ),
                          ),
                        ),

                        // Bottom padding to account for SafeArea bottom: false
                        SizedBox(height: isVeryCompact ? 8 : (isCompact ? 16 : 24)),
                      ],
                      ),
                    ),
                  );
                },
              ),
              
              // Break prompt overlay
              if (_showBreakPrompt) _buildBreakPrompt(context),
              
              // Swipe hint at bottom - hidden in compact mode to save space
              // if (_showControls)
              //   Positioned(
              //     bottom: 8,
              //     left: 0,
              //     right: 0,
              //     child: Center(
              //       child: Text(
              //         'Swipe down to exit',
              //         style: TextStyle(
              //           color: Colors.white.withValues(alpha: 0.3),
              //           fontSize: 12,
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final sessionDuration = _sessionStart != null
        ? DateTime.now().difference(_sessionStart!)
        : Duration.zero;
    final hours = sessionDuration.inHours;
    final minutes = sessionDuration.inMinutes % 60;
    
    return Row(
      children: [
        Semantics(
          label: 'Close body double mode',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: _exitScreen,
            tooltip: 'Exit focus mode',
          ),
        ),
        const Spacer(),
        // Session time
        Semantics(
          label: 'Session time: ${hours > 0 ? '$hours hours and ' : ''}$minutes minutes',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                hours > 0 
                    ? '${hours}h ${minutes}m' 
                    : '${minutes}m',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Completed pomodoros
        if (_completedPomodoros > 0)
          Semantics(
            label: '$_completedPomodoros focus sessions completed',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(width: 2),
                Text(
                  '$_completedPomodoros',
                  style: TextStyle(
                    color: Colors.orange.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        const SizedBox(width: 48), // Balance the close button
      ],
    );
  }

  Widget _buildAvatar(
    BuildContext context, {
    double outerSize = 120,
    double innerSize = 80,
  }) {
    const baseColor = Color(0xFF6366f1);
    final reduceAnimations = shouldReduceMotion(context);
    
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = reduceAnimations ? 0.0 : _pulseController.value;
          final scale = 1.0 + (pulse * 0.025);
          final glowOpacity = 0.2 + (pulse * 0.08);

          return Semantics(
            label: 'Digital companion presence indicator',
            excludeSemantics: true,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: outerSize,
                height: outerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: baseColor.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: glowOpacity),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          baseColor.withValues(alpha: 0.8),
                          baseColor.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: 32,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEncouragementMessage(
    BuildContext context, {
    double fontSize = 18,
    double height = 60,
  }) {
    final reduceAnimations = shouldReduceMotion(context);
    
    final message = Text(
      _encouragements[_currentMessageIndex],
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.8),
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
    
    return Semantics(
      label: 'Encouragement: ${_encouragements[_currentMessageIndex]}',
      liveRegion: true,
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduceAnimations ? 0 : 500),
        child: SizedBox(
          key: ValueKey(_currentMessageIndex),
          height: height,
          child: Center(
            child: reduceAnimations 
                ? message 
                : message.animate().fadeIn(duration: 500.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(
    BuildContext context, {
    EdgeInsets padding = const EdgeInsets.all(20),
    double bodyFontSize = 16,
  }) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        final task = provider.activeTask;
        final step = task?.currentStep;
        
        if (step == null) {
          return const SizedBox.shrink();
        }
        
        return Semantics(
          label: 'Current step: ${step.action}',
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CURRENT FOCUS',
                  style: TextStyle(
                    color: Color(0xFF818cf8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    step.action,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: bodyFontSize,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimer(
    BuildContext context, {
    double ringSize = 160,
    double timeFontSize = 48,
    bool compact = false,
  }) {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    final isBreak = !_isWorkSession;
    final sessionLabel = isBreak ? 'Break Time' : 'Focus Time';
    
    // Progress for visual ring
    final totalSeconds = _isWorkSession ? 25 * 60 : 5 * 60;
    final progress = 1 - (_secondsRemaining / totalSeconds);
    
    return Semantics(
      label: '$sessionLabel: $minutes minutes and $seconds seconds remaining',
      child: Column(
        children: [
          // Session type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isBreak 
                  ? Colors.green.withValues(alpha: 0.2) 
                  : const Color(0xFF6366f1).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              sessionLabel,
              style: TextStyle(
                color: isBreak 
                    ? Colors.green.shade300 
                    : const Color(0xFF818cf8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          
          // Timer display with progress ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: compact ? 3 : 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isBreak ? Colors.green.shade400 : const Color(0xFF6366f1),
                  ),
                ),
              ),
              // Time display
              Text(
                timeString,
                style: TextStyle(
                  fontSize: timeFontSize,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 4,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 20),
          
          // Keep controls in the layout so auto-hide does not shift content.
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset button
                Semantics(
                  label: 'Reset timer',
                  button: true,
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.6)),
                    onPressed: _resetTimer,
                    tooltip: 'Reset',
                  ),
                ),
                const SizedBox(width: 16),
                
                // Play/Pause button
                Semantics(
                  label: _timerRunning ? 'Pause timer' : 'Start timer',
                  button: true,
                  child: SizedBox(
                    width: compact ? 56 : 64,
                    height: compact ? 56 : 64,
                    child: ElevatedButton(
                      onPressed: _toggleTimer,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFF6366f1),
                        foregroundColor: Colors.white,
                      ),
                      child: Icon(
                        _timerRunning ? Icons.pause : Icons.play_arrow,
                        size: compact ? 28 : 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Skip button
                Semantics(
                  label: _isWorkSession ? 'Skip to break' : 'Skip to work session',
                  button: true,
                  child: IconButton(
                    icon: Icon(Icons.skip_next, color: Colors.white.withValues(alpha: 0.6)),
                    onPressed: _skipSession,
                    tooltip: _isWorkSession ? 'Take break' : 'Back to work',
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioControls(
    BuildContext context, {
    bool compact = false,
  }) {
    final currentSound = _ambientAudio.currentSound;
    final isPremium = context.watch<PurchaseService>().isPremium;
    
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: AmbientSound.values.map((sound) {
              final isSelected = currentSound == sound;
              final isLocked = sound.isPremium && !isPremium;
              return Expanded(
                child: Semantics(
                  label: '${AmbientAudioService.getLabel(sound)} sound${isLocked ? ', requires Pro' : ''}',
                  button: true,
                  selected: isSelected,
                  inMutuallyExclusiveGroup: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectSound(sound),
                    child: ExcludeSemantics(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      constraints: const BoxConstraints(
                        minHeight: kMinInteractiveDimension,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 8,
                        vertical: compact ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF6366f1).withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected 
                            ? Border.all(color: const Color(0xFF6366f1))
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                _getSoundIcon(sound),
                                size: compact ? 20 : 24,
                                color: isSelected 
                                    ? const Color(0xFF818cf8)
                                    : isLocked
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.75),
                              ),
                              if (isLocked)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Icon(
                                    Icons.lock,
                                    size: 10,
                                    color: Colors.amber.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: compact ? 2 : 4),
                          Text(
                            AmbientAudioService.getLabel(sound),
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              color: isSelected 
                                  ? const Color(0xFF818cf8)
                                  : isLocked
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
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
    );
  }

  Widget _buildParticles(BuildContext context) {
    if (shouldReduceMotion(context)) {
      return const SizedBox.shrink();
    }
    
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          animation: _particleController,
          color: const Color(0xFF6366f1),
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildBreakPrompt(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Semantics(
          label: 'Break time! Would you like to continue with another focus session?',
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d44),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isWorkSession ? Icons.coffee : Icons.self_improvement,
                  size: 48,
                  color: const Color(0xFF6366f1),
                ),
                const SizedBox(height: 16),
                Text(
                  _isWorkSession ? 'Time for a break!' : 'Ready to focus again?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isWorkSession 
                      ? 'You earned it. Take 5 minutes.' 
                      : 'One more pomodoro?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Semantics(
                      label: 'End session',
                      button: true,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _showBreakPrompt = false);
                          _exitScreen();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Text("I'm done"),
                      ),
                    ),
                    Semantics(
                      label: _isWorkSession ? 'Start break' : 'Start another focus session',
                      button: true,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showBreakPrompt = false;
                            _isWorkSession = !_isWorkSession;
                            _secondsRemaining = _isWorkSession ? 25 * 60 : 5 * 60;
                            _timerRunning = true;
                          });
                          _startTimerTick();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366f1),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_isWorkSession ? 'Take break' : 'One more!'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods
  IconData _getSoundIcon(AmbientSound sound) {
    switch (sound) {
      case AmbientSound.none:
        return Icons.volume_off;
      case AmbientSound.cafe:
        return Icons.coffee;
      case AmbientSound.rain:
        return Icons.water_drop;
      case AmbientSound.whiteNoise:
        return Icons.waves;
      case AmbientSound.nature:
        return Icons.park;
      case AmbientSound.fireplace:
        return Icons.local_fire_department;
    }
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _onTimerTick();
      if (!_timerRunning) return; // Finished while catching up.
      _timer?.cancel();
      setState(() {
        _timerRunning = false;
        _timerEndsAt = null;
      });
    } else {
      setState(() {
        _timerRunning = true;
      });
      _startTimerTick();
    }
  }

  void _startTimerTick() {
    _timer?.cancel();
    _timerEndsAt = clock.now().add(Duration(seconds: _secondsRemaining));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTimerTick());
  }

  void _onTimerTick() {
    if (!mounted || !_timerRunning || _timerEndsAt == null) return;

    final remainingMs = _timerEndsAt!.difference(clock.now()).inMilliseconds;
    final remaining = remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
    if (remaining > 0) {
      if (remaining != _secondsRemaining) {
        setState(() => _secondsRemaining = remaining);
      }
      return;
    }

    _timer?.cancel();
    HapticFeedback.mediumImpact();
    // Play gentle chime
    _soundService.playTimerEnd();
    setState(() {
      _secondsRemaining = 0;
      _timerRunning = false;
      _timerEndsAt = null;
      _showBreakPrompt = true;
      // A pomodoro counts once its focus period actually runs out.
      if (_isWorkSession) {
        _completedPomodoros++;
        context.read<TaskProvider>().recordPomodoroCompleted();
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _timerEndsAt = null;
      _secondsRemaining = _isWorkSession ? 25 * 60 : 5 * 60;
    });
  }

  void _skipSession() {
    _timer?.cancel();
    setState(() {
      _timerEndsAt = null;
      if (_isWorkSession) {
        // Skipping focus time doesn't count as a completed pomodoro.
        _isWorkSession = false;
        _secondsRemaining = 5 * 60;
      } else {
        // Skip back to work
        _isWorkSession = true;
        _secondsRemaining = 25 * 60;
      }
      _timerRunning = false;
    });
  }

  Future<void> _selectSound(AmbientSound sound) async {
    // Check if premium sound and user isn't premium
    final purchases = context.read<PurchaseService>();
    if (sound.isPremium && !purchases.isPremium) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }
    
    await _ambientAudio.play(sound);
    if (mounted) {
      setState(() {});
    }
  }
}

/// Floating particle for calm visual effect
class _FloatingParticle {
  double x;
  double y;
  final double size;
  final int driftCycles;
  final double opacity;

  _FloatingParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.driftCycles,
    required this.opacity,
  });
}

/// Custom painter for floating particles
class _ParticlePainter extends CustomPainter {
  final List<_FloatingParticle> particles;
  final Animation<double> animation;
  final Color color;

  // Repaints straight from the animation without rebuilding widgets.
  _ParticlePainter({
    required this.particles,
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final time = animation.value;
    for (final particle in particles) {
      // Integer cycle counts make the controller's loop boundary seamless.
      final y = (particle.y - (time * particle.driftCycles)) % 1.0;
      final x = particle.x + sin(time * 2 * pi + particle.y * 10) * 0.02;
      final edgeDistance = min(y, 1 - y);
      final edgeFade = Curves.easeInOut.transform(
        (edgeDistance / 0.1).clamp(0.0, 1.0),
      );

      final paint = Paint()
        ..color = color.withValues(alpha: particle.opacity * edgeFade)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.particles != particles || oldDelegate.color != color;
}
