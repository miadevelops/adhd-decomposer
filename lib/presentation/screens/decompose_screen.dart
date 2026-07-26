import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/task_provider.dart';
import '../../core/constants/strings.dart';
import '../../data/services/siri_service.dart';
import 'task_summary_screen.dart';
import 'paywall_screen.dart';

/// Minimum touch target size for accessibility (48x48dp per WCAG guidelines)
const double kMinTouchTarget = 48.0;

class DecomposeScreen extends StatefulWidget {
  const DecomposeScreen({super.key});

  @override
  State<DecomposeScreen> createState() => _DecomposeScreenState();
}

class _DecomposeScreenState extends State<DecomposeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUsageLimit();
      // Auto-focus input field for accessibility
      _focusNode.requestFocus();
    });
  }
  
  void _checkUsageLimit() {
    final provider = context.read<TaskProvider>();
    if (!provider.canDecompose) {
      // Show paywall immediately if limit reached
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaywallScreen(
            showSkip: false,
            onPurchaseComplete: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  /// Check if animations should be reduced
  bool _shouldReduceAnimations(BuildContext context) {
    final provider = context.read<TaskProvider>();
    return provider.reduceAnimations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text(AppStrings.newTask),
        ),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return _buildLoadingState(context);
          }
          return _buildInputState(context, provider);
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final reduceAnimations = _shouldReduceAnimations(context);
    
    final content = Center(
      child: Semantics(
        label: 'Breaking down your task into tiny steps. Please wait.',
        liveRegion: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
                semanticsLabel: 'Loading',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.decomposing,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Breaking your task into tiny steps...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
    
    if (reduceAnimations) {
      return content;
    }
    
    return content.animate().fadeIn();
  }

  Widget _buildInputState(BuildContext context, TaskProvider provider) {
    final remaining = provider.remainingFreeDecompositions;
    final showRemainingBanner = !provider.isPremium && 
                                 !provider.hasCustomApiKey && 
                                 remaining > 0 && 
                                 remaining <= 3;
    final reduceAnimations = _shouldReduceAnimations(context);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showRemainingBanner) ...[
            _buildRemainingBanner(context, remaining, reduceAnimations),
            const SizedBox(height: 16),
          ],
          Semantics(
            header: true,
            child: Text(
              AppStrings.whatNeedsToBeDone,
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "I'll break it down into tiny, doable steps.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Semantics(
            label: 'Enter what you need to do',
            hint: 'Type your task here, then tap Break it down',
            textField: true,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: AppStrings.taskPlaceholder,
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _decompose(provider),
            ),
          ),
          const SizedBox(height: 16),
          _buildSuggestions(context),
          const Spacer(),
          Semantics(
            label: 'Break it down into steps',
            button: true,
            excludeSemantics: true,
            enabled: _controller.text.trim().isNotEmpty,
            hint: _controller.text.trim().isEmpty 
                ? 'Enter a task first' 
                : 'Double tap to break down your task',
            child: SizedBox(
              height: kMinTouchTarget,
              child: ElevatedButton(
                onPressed: _controller.text.trim().isEmpty 
                  ? null 
                  : () => _decompose(provider),
                child: const Text(AppStrings.breakItDown),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildRemainingBanner(BuildContext context, int remaining, bool reduceAnimations) {
    final banner = Semantics(
      label: remaining == 1
          ? 'Warning: Last free breakdown. Upgrade for unlimited breakdowns.'
          : '$remaining free breakdowns remaining.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: remaining == 1 
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              remaining == 1 ? Icons.warning_amber_rounded : Icons.info_outline,
              color: remaining == 1 
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              semanticLabel: remaining == 1 ? 'Warning' : 'Information',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                remaining == 1
                    ? 'Last free breakdown! Upgrade for unlimited.'
                    : '$remaining free breakdowns left',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: remaining == 1
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            Semantics(
              label: 'Upgrade to premium',
              button: true,
              child: SizedBox(
                height: kMinTouchTarget,
                child: TextButton(
                  onPressed: () => _showPaywall(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Upgrade'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    
    if (reduceAnimations) {
      return banner;
    }
    
    return banner.animate().fadeIn().slideY(begin: -0.3, end: 0);
  }

  Widget _buildSuggestions(BuildContext context) {
    final suggestions = [
      'Clean the kitchen',
      'Do laundry',
      'Process inbox',
      'Organize desk',
    ];

    return Semantics(
      label: 'Quick task suggestions',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions.map((s) => Semantics(
          label: 'Use suggestion: $s',
          button: true,
          excludeSemantics: true,
          child: SizedBox(
            height: kMinTouchTarget,
            child: ActionChip(
              label: Text(s),
              onPressed: () {
                _controller.text = s;
                // Announce selection for screen readers
                SemanticsService.announce('Selected: $s', TextDirection.ltr);
              },
            ),
          ),
        )).toList(),
      ),
    );
  }
  
  void _showPaywall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          onSkip: () => Navigator.of(context).pop(),
          onPurchaseComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _decompose(TaskProvider provider) async {
    if (_controller.text.trim().isEmpty) return;
    
    // Check if can decompose before attempting
    if (!provider.canDecompose) {
      _showPaywall(context);
      return;
    }
    
    // Donate intent for Siri to learn this pattern
    SiriService().donateDecomposeStarted('task');
    
    // Announce loading state for screen readers
    SemanticsService.announce('Breaking down your task. Please wait.', TextDirection.ltr);

    final task = await provider.decomposeTask(_controller.text.trim());
    
    if (task != null && mounted) {
      provider.setActiveTask(task);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TaskSummaryScreen()),
      );
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
      provider.clearError();
    }
  }
}
