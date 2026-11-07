import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/motion.dart';
import '../../../data/services/settings_service.dart';
import 'welcome_page.dart';
import 'challenge_page.dart';
import 'demo_page.dart';
import 'coach_picker_page.dart';
import 'features_preview_page.dart';
import '../paywall_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // Welcome, Challenge, Demo, Coach, Features. The paywall follows as an
  // optional final page and isn't counted as an onboarding step.
  static const int _stepCount = 5;
  static const int _paywallPage = _stepCount;
  
  String? _selectedChallenge;
  
  late final SettingsService _settings;
  
  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _initSettings();
  }
  
  Future<void> _initSettings() async {
    await _settings.initialize();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  Duration get _pageDuration => shouldReduceMotion(context)
      ? Duration.zero
      : const Duration(milliseconds: 400);

  void _goToPage(int page) {
    if (_pageDuration == Duration.zero) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(
        page,
        duration: _pageDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _paywallPage) _goToPage(_currentPage + 1);
  }

  void _previousPage() {
    if (_currentPage > 0) _goToPage(_currentPage - 1);
  }

  void _skipToEnd() => _goToPage(_paywallPage);
  
  void _onChallengeSelected(String challenge) {
    setState(() => _selectedChallenge = challenge);
    _settings.userChallenge = challenge;
    _nextPage();
  }
  
  void _completeOnboarding() {
    _settings.onboardingComplete = true;
    widget.onComplete();
  }
  
  @override
  Widget build(BuildContext context) {
    final onPaywall = _currentPage == _paywallPage;
    final reduceMotion = shouldReduceMotion(context);

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previousPage();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: kMinInteractiveDimension,
                      child: _currentPage > 0
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back),
                              tooltip: 'Back',
                              onPressed: _previousPage,
                            )
                          : null,
                    ),
                    Expanded(
                      child: onPaywall
                          ? const SizedBox.shrink()
                          : Semantics(
                              label:
                                  'Step ${_currentPage + 1} of $_stepCount',
                              excludeSemantics: true,
                              child: Row(
                                children: List.generate(_stepCount, (index) {
                                  final bar = Container(
                                    height: 4,
                                    margin: EdgeInsets.only(
                                      right: index < _stepCount - 1 ? 8 : 0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: index <= _currentPage
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.2),
                                    ),
                                  );
                                  return Expanded(
                                    child: reduceMotion
                                        ? bar
                                        : bar
                                            .animate(
                                              target:
                                                  index <= _currentPage ? 1 : 0,
                                            )
                                            .scaleX(
                                              begin: 0.5,
                                              end: 1,
                                              alignment: Alignment.centerLeft,
                                            )
                                            .fadeIn(),
                                  );
                                }),
                              ),
                            ),
                    ),
                    if (!onPaywall)
                      TextButton(
                        onPressed: _skipToEnd,
                        child: const Text('Skip'),
                      )
                    else
                      const SizedBox(width: kMinInteractiveDimension),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    WelcomePage(onNext: _nextPage),
                    ChallengePage(
                      selectedChallenge: _selectedChallenge,
                      onChallengeSelected: _onChallengeSelected,
                    ),
                    DemoPage(onNext: _nextPage),
                    CoachPickerPage(onNext: _nextPage),
                    FeaturesPreviewPage(onNext: _nextPage),
                    PaywallScreen(
                      showSkip: true,
                      onSkip: _completeOnboarding,
                      onPurchaseComplete: _completeOnboarding,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
