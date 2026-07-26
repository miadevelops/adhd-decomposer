import 'package:adhd_decomposer/data/services/purchase_service.dart';
import 'package:adhd_decomposer/presentation/providers/task_provider.dart';
import 'package:adhd_decomposer/presentation/screens/body_double_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Body Double can be disposed without an ancestor lookup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TaskProvider()),
          ChangeNotifierProvider(create: (_) => PurchaseService()),
        ],
        child: const MaterialApp(home: BodyDoubleScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('companion pulse does not move surrounding UI', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TaskProvider()),
          ChangeNotifierProvider(create: (_) => PurchaseService()),
        ],
        child: const MaterialApp(home: BodyDoubleScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    final message = find.text("You're doing great. Keep going.");
    final initialCenter = tester.getCenter(message);
    await tester.pump(const Duration(seconds: 2));

    expect(tester.getCenter(message), initialCenter);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

  testWidgets('soundscapes rely on system volume', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TaskProvider()),
          ChangeNotifierProvider(create: (_) => PurchaseService()),
        ],
        child: const MaterialApp(home: BodyDoubleScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(Slider), findsNothing);
    expect(find.byIcon(Icons.volume_up), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

}
