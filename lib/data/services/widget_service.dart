import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../models/task.dart';

/// Service for managing home screen widgets
class WidgetService {
  static const String _appGroupId = 'group.com.manuelpa.tinysteps';
  static const String _androidWidgetName = 'CurrentTaskWidget';
  static const String _quickAddWidgetName = 'QuickAddWidget';
  static const _pinChannel = MethodChannel('com.manuelpa.tinysteps/widget_pin');
  
  /// Initialize the widget service
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint('WidgetService: Error initializing - $e');
    }
  }
  
  /// Check if the device supports programmatic widget pinning (Android 8.0+)
  static Future<bool> isWidgetPinSupported() async {
    if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) return false;
    try {
      final result = await _pinChannel.invokeMethod<bool>('isWidgetPinSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetService: Error checking pin support - $e');
      return false;
    }
  }
  
  /// Request the system to pin the widget to the home screen (Android 8.0+).
  /// Returns true if the request was sent (user still needs to confirm).
  static Future<bool> requestPinWidget({String widgetClass = 'CurrentTaskWidget'}) async {
    if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) return false;
    try {
      final result = await _pinChannel.invokeMethod<bool>(
        'requestPinWidget',
        {'widgetClass': widgetClass},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetService: Error requesting pin widget - $e');
      return false;
    }
  }
  
  /// Update widget data with current task information
  static Future<void> updateCurrentTask(Task? task) async {
    try {
      if (task != null && !task.isCompleted) {
        await HomeWidget.saveWidgetData<String>('task_name', task.title);
        await HomeWidget.saveWidgetData<String>(
          'current_step', 
          task.currentStep?.action ?? 'All steps completed!'
        );
        await HomeWidget.saveWidgetData<int>('current_step_index', task.currentStepIndex);
        await HomeWidget.saveWidgetData<int>('total_steps', task.steps.length);
        await HomeWidget.saveWidgetData<bool>('has_active_task', true);
      } else {
        await HomeWidget.saveWidgetData<String>('task_name', 'No active task');
        await HomeWidget.saveWidgetData<String>('current_step', 'Tap to start a task');
        await HomeWidget.saveWidgetData<int>('current_step_index', 0);
        await HomeWidget.saveWidgetData<int>('total_steps', 0);
        await HomeWidget.saveWidgetData<bool>('has_active_task', false);
      }
      
      // Update both Android widgets
      await _updateAndroidWidgets();
    } catch (e) {
      debugPrint('WidgetService: Error updating task - $e');
    }
  }
  
  /// Clear widget data (when no active task)
  static Future<void> clearWidgetData() async {
    await updateCurrentTask(null);
  }
  
  /// Update Android widgets
  static Future<void> _updateAndroidWidgets() async {
    try {
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
      await HomeWidget.updateWidget(
        name: _quickAddWidgetName,
        androidName: _quickAddWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetService: Error updating Android widgets - $e');
    }
  }
  
  /// Handle widget click events (returns the URI path)
  static Future<Uri?> getInitialUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('WidgetService: Error getting initial URI - $e');
      return null;
    }
  }
  
  /// Stream of widget click events
  static Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;
}
