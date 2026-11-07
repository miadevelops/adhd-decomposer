import 'package:flutter/widgets.dart';

/// Lets a `Column` that uses `Spacer`/`Expanded` fill the screen when there
/// is room, and scroll instead of overflowing when there isn't (large text
/// scale, small phones, landscape, split screen).
class ScrollFill extends StatelessWidget {
  final Widget child;

  const ScrollFill({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
