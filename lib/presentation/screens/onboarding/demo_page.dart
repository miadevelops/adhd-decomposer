import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/motion.dart';

class DemoPage extends StatefulWidget {
  final VoidCallback onNext;
  
  const DemoPage({super.key, required this.onNext});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  bool _isDecomposing = false;
  bool _showSteps = false;
  int _visibleSteps = 0;
  int _completedSteps = 0;
  bool _showCelebration = false;
  Timer? _autoCompleteTimer;
  
  final _demoTask = "Clean my room";
  final _demoSteps = [
    "Grab a trash bag from the kitchen",
    "Walk around and pick up obvious trash",
    "Put dirty clothes in the laundry basket",
    "Make your bed (just pull the covers up!)",
    "Clear off your desk surface",
    "Take a breath - you did it! 🎉",
  ];
  
  @override
  void dispose() {
    _autoCompleteTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _startDemo() async {
    if (_isDecomposing || _showSteps) return;
    setState(() => _isDecomposing = true);
    
    // Simulate AI thinking
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    setState(() {
      _isDecomposing = false;
      _showSteps = true;
    });
    
    // Reveal steps one by one
    for (int i = 0; i < _demoSteps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        setState(() => _visibleSteps = i + 1);
      }
    }
    
    // Start auto-complete timer after all steps are visible
    _startAutoCompleteTimer();
  }
  
  void _startAutoCompleteTimer() {
    _autoCompleteTimer?.cancel();
    
    // Auto-complete current step after 2.5 seconds of inactivity
    _autoCompleteTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _completedSteps < _demoSteps.length && !_showCelebration) {
        _completeStep(_completedSteps);
      }
    });
  }
  
  Future<void> _completeStep(int index) async {
    if (index != _completedSteps) return;
    
    _autoCompleteTimer?.cancel();
    
    setState(() => _completedSteps++);
    
    // If all steps completed, show celebration
    if (_completedSteps == _demoSteps.length) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() => _showCelebration = true);
      }
    } else {
      // Continue auto-complete for next step
      _startAutoCompleteTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          // Title - compact
          Text(
            'See it in action',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn().slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 4),
          
          Text(
            'Watch how Tiny Steps breaks down a task',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 16),
          
          // Demo card - takes most of the space
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: _showCelebration
                  ? _buildCelebration(context)
                  : _showSteps
                      ? _buildSteps(context)
                      : _isDecomposing
                          ? _buildDecomposing(context)
                          : _buildInput(context),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Continue after the celebration; until then the demo is skippable.
          if (_showCelebration)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onNext,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('That\'s amazing! Continue'),
              ),
            ).animate().fadeIn().slideY(begin: 0.5, end: 0)
          else
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  _autoCompleteTimer?.cancel();
                  widget.onNext();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Skip demo'),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInput(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Fake input field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _demoTask,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
        
        const SizedBox(height: 20),
        
        // Tap to start
        FilledButton.icon(
          onPressed: _startDemo,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Break it down'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),
      ],
    );
  }
  
  Widget _buildDecomposing(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final dot = Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            );
            if (shouldReduceMotion(context)) return dot;
            return dot
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(delay: Duration(milliseconds: index * 200))
                .then()
                .fadeOut(delay: const Duration(milliseconds: 400));
          }),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Breaking down "$_demoTask"...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSteps(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text(
                _demoTask,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '~15 min',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Steps list - expanded to fill
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _demoSteps.length,
            itemBuilder: (context, index) {
              if (index >= _visibleSteps) {
                return const SizedBox.shrink();
              }
              
              final isCompleted = index < _completedSteps;
              final isCurrent = index == _completedSteps;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: isCompleted
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : isCurrent
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: isCurrent ? () => _completeStep(index) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: isCurrent
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Checkbox
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isCompleted
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                                width: 2,
                              ),
                            ),
                            child: isCompleted
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          
                          const SizedBox(width: 10),
                          
                          // Step text
                          Expanded(
                            child: Text(
                              _demoSteps[index],
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                color: isCompleted
                                    ? Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)
                                    : null,
                              ),
                            ),
                          ),
                          
                          // Tap hint for current
                          if (isCurrent)
                            shouldReduceMotion(context)
                                ? _buildTapHint(context)
                                : _buildTapHint(context)
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .fadeIn()
                                    .then(delay: 800.ms)
                                    .fadeOut(duration: 400.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildTapHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Tap!',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCelebration(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Confetti emoji
        const Text(
          '🎉',
          style: TextStyle(fontSize: 56),
        )
            .animate(
              onPlay: (c) => shouldReduceMotion(context)
                  ? c.stop()
                  : c.repeat(reverse: true),
            )
            .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15))
            .then()
            .shake(),
        
        const SizedBox(height: 12),
        
        Text(
          'Task complete!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ).animate().fadeIn().slideY(begin: 0.3, end: 0),
        
        const SizedBox(height: 8),
        
        Text(
          'See how easy that was?\nTiny steps make big tasks feel doable.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          textAlign: TextAlign.center,
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3, end: 0),
      ],
    );
  }
}
