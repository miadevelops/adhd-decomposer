import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:adhd_decomposer/data/models/task.dart';
import 'package:adhd_decomposer/presentation/providers/task_provider.dart';
import 'package:adhd_decomposer/presentation/screens/execute_screen.dart';
import 'package:adhd_decomposer/presentation/screens/onboarding/challenge_page.dart';
import 'package:adhd_decomposer/presentation/screens/onboarding/welcome_page.dart';
import 'package:adhd_decomposer/presentation/screens/templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

class _TestTaskProvider extends TaskProvider {
  @override
  bool get confettiEnabled => false;

  @override
  bool get hapticEnabled => false;

  @override
  bool get reduceAnimations => true;

  @override
  bool get soundEnabled => false;
}

void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _scaled(Widget child) {
  return MaterialApp(
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(2),
      ),
      child: app!,
    ),
    home: Scaffold(body: child),
  );
}

bool _hasTap(WidgetTester tester, Finder finder) {
  return tester
      .getSemantics(finder)
      .getSemanticsData()
      .hasAction(SemanticsAction.tap);
}

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('text_scaling_test');
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  final onboardingPages = <String, Widget Function()>{
    'welcome': () => WelcomePage(onNext: () {}),
    'challenge': () => ChallengePage(
          selectedChallenge: null,
          onChallengeSelected: (_) {},
        ),
  };

  for (final entry in onboardingPages.entries) {
    testWidgets('${entry.key} page fits a small phone at 200% text', (
      tester,
    ) async {
      _useSmallPhone(tester);
      await tester.pumpWidget(_scaled(entry.value()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('execute screen scrolls at 200% text and keeps tap actions', (
    tester,
  ) async {
    _useSmallPhone(tester);
    final semantics = tester.ensureSemantics();

    final provider = _TestTaskProvider();
    provider.setActiveTask(
      Task(
        id: 'task-1',
        title: 'Clean the kitchen',
        steps: [
          TaskStep(
            id: 'step-1',
            action: 'Put every dirty dish next to the sink',
            estimatedMinutes: 5,
          ),
          TaskStep(id: 'step-2', action: 'Wipe counters', estimatedMinutes: 5),
        ],
        totalEstimatedMinutes: 10,
        createdAt: DateTime(2026),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<TaskProvider>.value(
        value: provider,
        child: MaterialApp(
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: app!,
          ),
          home: const ExecuteScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    final done = find.widgetWithText(ElevatedButton, 'Done!');
    expect(done, findsOneWidget);
    expect(
      tester.getSemantics(done).getSemanticsData().hasAction(
            SemanticsAction.tap,
          ),
      isTrue,
    );

    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('challenge cards keep their tap action for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChallengePage(
            selectedChallenge: null,
            onChallengeSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.bySemanticsLabel(RegExp('Getting Overwhelmed'));
    expect(card, findsOneWidget);
    expect(_hasTap(tester, card), isTrue);

    tester.semantics.tap(find.semantics.byLabel(RegExp('Getting Overwhelmed')));
    await tester.pump();
    expect(selected, isNotNull);

    semantics.dispose();
  });

  testWidgets('template cards and category chips keep their tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ChangeNotifierProvider<TaskProvider>.value(
        value: _TestTaskProvider(),
        child: const MaterialApp(home: TemplatesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final chips = find.bySemanticsLabel(RegExp(r'category$'));
    expect(chips, findsWidgets);
    expect(_hasTap(tester, chips.first), isTrue);

    final cards = find.bySemanticsLabel(RegExp(r'minutes\. \d+ steps$'));
    expect(cards, findsWidgets);
    expect(_hasTap(tester, cards.first), isTrue);

    semantics.dispose();
  });
}
