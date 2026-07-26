import 'package:flutter/foundation.dart';
import '../models/task.dart';

/// Analytics service for tracking user events
/// Currently a stub implementation - uses debugPrint (stripped in release)
/// Replace with real analytics (Firebase, Mixpanel, etc.) later
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();
  
  bool _initialized = false;
  
  /// Initialize analytics service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _log('Analytics initialized');
  }
  
  /// Track a custom event
  void trackEvent(String eventName, [Map<String, dynamic>? parameters]) {
    _log('EVENT: $eventName${parameters != null ? ' $parameters' : ''}');
  }
  
  /// Track screen view
  void trackScreen(String screenName) {
    _log('SCREEN: $screenName');
  }
  
  /// Set a user property
  void setUserProperty(String name, String value) {
    _log('USER_PROPERTY: $name = $value');
  }
  
  // Convenience methods for common events (static for ease of use)
  
  /// Track task completion
  static void trackTaskCompleted(Task task) {
    _instance.trackEvent('task_completed', {
      'steps_completed': task.completedStepsCount,
      'steps_skipped': task.steps.where((s) => s.isSkipped).length,
    });
  }
  
  /// Track step completion
  static void trackStepCompleted({bool skipped = false}) {
    _instance.trackEvent('step_completed', {'skipped': skipped});
  }
  
  /// Track template usage
  static void trackTemplateUsed(String templateId) {
    _instance.trackEvent('template_used', {'template_id': templateId});
  }
  
  /// Track feedback submission
  static void trackFeedbackSubmitted({required bool hasEmail}) {
    _instance.trackEvent('feedback_submitted', {'has_email': hasEmail});
  }
  
  /// Track rate app prompt response
  static void trackRateAppResponse(String response) {
    _instance.trackEvent('rate_app_response', {'response': response});
  }
  
  /// Track share action
  static void trackShare(String contentType) {
    _instance.trackEvent('share', {'content_type': contentType});
  }
  
  void _log(String message) {
    debugPrint('[Analytics] $message');
  }
}
