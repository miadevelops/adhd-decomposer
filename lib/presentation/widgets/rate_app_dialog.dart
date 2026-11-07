import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/analytics_service.dart';
import '../screens/feedback_screen.dart';

/// A non-intrusive dialog asking users to rate the app
/// Shows only after significant usage and respects user's choice
class RateAppDialog extends StatelessWidget {
  final SettingsService settings;
  final VoidCallback? onDismiss;
  
  const RateAppDialog({
    super.key,
    required this.settings,
    this.onDismiss,
  });
  
  /// Shows the prompt if it's due and records that it was shown, so each
  /// prompt counts once no matter which button (if any) is pressed.
  static Future<void> showIfNeeded(BuildContext context, SettingsService settings) async {
    if (!settings.shouldShowRatePrompt) return;
    settings.recordRatePromptShown();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RateAppDialog(settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            Icons.favorite,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Enjoying Tiny Steps?'),
          ),
        ],
      ),
      content: const Text(
        'Your feedback helps us make the app better for everyone with ADHD.',
        style: TextStyle(fontSize: 15),
      ),
      actions: [
        // Ask me later
        TextButton(
          onPressed: () {
            AnalyticsService.trackRateAppResponse('ask_later');
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: const Text('Ask me later'),
        ),
        // Not really - go to feedback
        TextButton(
          onPressed: () {
            AnalyticsService.trackRateAppResponse('not_really');
            // The dialog's context is gone once it's popped, so grab the
            // navigator first.
            final navigator = Navigator.of(context);
            navigator.pop();
            // Navigate to feedback form
            navigator.push(
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            );
          },
          child: const Text('Not really'),
        ),
        // Love it! - open app store
        FilledButton.icon(
          onPressed: () async {
            AnalyticsService.trackRateAppResponse('love_it');
            settings.recordUserRated();
            Navigator.of(context).pop();
            
            // Try native in-app review, fall back to store listing
            final InAppReview inAppReview = InAppReview.instance;
            
            if (await inAppReview.isAvailable()) {
              await inAppReview.requestReview();
            } else {
              // Open store listing directly
              await inAppReview.openStoreListing(
                appStoreId: '6479684930', // Replace with your App Store ID
              );
            }
            
            onDismiss?.call();
          },
          icon: const Icon(Icons.star, size: 18),
          label: const Text('Love it!'),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    );
  }
}
