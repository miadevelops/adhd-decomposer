import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../presentation/providers/task_provider.dart';

/// Whether decorative motion should be skipped.
///
/// True when the in-app "Reduce animations" setting is on, or when the OS
/// asks apps to remove animations (iOS Reduce Motion / Android "Remove
/// animations"). Pass [listen] when called from `build` so the widget
/// rebuilds if the in-app setting changes.
bool shouldReduceMotion(BuildContext context, {bool listen = false}) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return true;
  try {
    return Provider.of<TaskProvider>(context, listen: listen).reduceAnimations;
  } on ProviderNotFoundException {
    return false;
  }
}
