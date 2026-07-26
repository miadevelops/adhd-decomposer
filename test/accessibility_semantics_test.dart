import 'dart:ui' show SemanticsFlag;

import 'package:adhd_decomposer/presentation/screens/onboarding/challenge_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('challenge cards expose button and selection semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChallengePage(
            selectedChallenge: 'overwhelm',
            onChallengeSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Getting Overwhelmed. Tasks feel too big to start',
      ),
      findsOneWidget,
    );
    final semanticsData = tester
        .getSemantics(
          find.bySemanticsLabel(
            'Getting Overwhelmed. Tasks feel too big to start',
          ),
        )
        .getSemanticsData();
    expect(
      semanticsData.hasFlag(SemanticsFlag.isButton),
      isTrue,
    );
    expect(
      semanticsData.hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
    semantics.dispose();
  });
}
