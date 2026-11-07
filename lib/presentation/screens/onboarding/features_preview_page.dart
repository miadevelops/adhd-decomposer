import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/services/widget_service.dart';

class FeaturesPreviewPage extends StatefulWidget {
  final VoidCallback onNext;
  
  const FeaturesPreviewPage({super.key, required this.onNext});

  @override
  State<FeaturesPreviewPage> createState() => _FeaturesPreviewPageState();
}

class _FeaturesPreviewPageState extends State<FeaturesPreviewPage> {
  final PageController _pageController = PageController();
  int _currentFeature = 0;
  bool _canPinWidget = false;
  bool _pinRequested = false;
  
  final List<_Feature> _features = [
    const _Feature(
      icon: Icons.timer_outlined,
      title: 'Time Blindness Alerts',
      description: '"You\'ve been on this 10 min"\n\nGentle nudges to keep you aware of time — no guilt, just awareness.',
      color: Color(0xFF4ECDC4),
    ),
    const _Feature(
      icon: Icons.people_outline,
      title: 'Body Double Mode',
      description: 'Ambient sounds + focus timer.\n\nLike having someone work alongside you.',
      color: Color(0xFF7BC47F),
    ),
    const _Feature(
      icon: Icons.widgets_outlined,
      title: 'Home Screen Widget',
      description: 'See your next step without opening the app.\n\nOne tap to jump back in.',
      color: Color(0xFFFF6B6B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkPinSupport();
  }

  Future<void> _checkPinSupport() async {
    if ((!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) {
      final supported = await WidgetService.isWidgetPinSupported();
      if (mounted) {
        setState(() => _canPinWidget = supported);
      }
    }
  }

  Future<void> _requestPin() async {
    final success = await WidgetService.requestPinWidget();
    if (mounted && success) {
      setState(() => _pinRequested = true);
    }
  }

  void _nextFeature() {
    if (_currentFeature < _features.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastFeature = _currentFeature == _features.length - 1;
    final isWidgetFeature = _currentFeature == 2;
    
    return Column(
      children: [
        // Feature cards
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentFeature = page),
            itemCount: _features.length,
            itemBuilder: (context, index) {
              final feature = _features[index];
              return _buildFeatureCard(context, feature, index);
            },
          ),
        ),
        
        // Page indicator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_features.length, (index) {
              final isActive = index == _currentFeature;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
        ),
        
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              // Widget-specific: Add Widget button
              if (isWidgetFeature && _canPinWidget) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pinRequested ? null : _requestPin,
                    icon: Icon(_pinRequested ? Icons.check_rounded : Icons.add_to_home_screen),
                    label: Text(_pinRequested ? 'Widget added!' : 'Add Widget Now'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Continue button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextFeature,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(isLastFeature ? 'Let\'s go!' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildFeatureCard(BuildContext context, _Feature feature, int index) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon in colored circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              feature.icon,
              size: 48,
              color: feature.color,
            ),
          ).animate().scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 400.ms,
            curve: Curves.elasticOut,
          ),
          
          const SizedBox(height: 40),
          
          // Title
          Text(
            feature.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 20),
          
          // Description
          Text(
            feature.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  
  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
