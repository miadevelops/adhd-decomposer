import 'dart:io';

import 'package:adhd_decomposer/data/models/task.dart';
import 'package:adhd_decomposer/presentation/providers/task_provider.dart';
import 'package:adhd_decomposer/presentation/screens/execute_screen.dart';
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

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('execute_timer_test');
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('focus timer continues between substeps', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _TestTaskProvider();
    final task = Task(
      id: 'task-1',
      title: 'Parent task',
      steps: [
        TaskStep(
          id: 'step-1',
          action: 'Parent step',
          estimatedMinutes: 5,
          subSteps: [
            TaskStep(
              id: 'substep-1',
              action: 'First substep',
              estimatedMinutes: 10,
            ),
            TaskStep(
              id: 'substep-2',
              action: 'Second substep',
              estimatedMinutes: 10,
            ),
          ],
        ),
      ],
      totalEstimatedMinutes: 5,
      createdAt: DateTime(2026),
    );
    provider.setActiveTask(task);

    await tester.pumpWidget(
      ChangeNotifierProvider<TaskProvider>.value(
        value: provider,
        child: const MaterialApp(home: ExecuteScreen()),
      ),
    );

    await tester.tap(find.text('10 min'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Done!'));
    await tester.pump();

    expect(task.currentStepIndex, 0);
    expect(task.steps.single.currentSubStepIndex, 1);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('09:59'), findsOneWidget);

    final alreadyBrokenText = find.text('Already broken down');
    final alreadyBrokenButton = find.ancestor(
      of: alreadyBrokenText,
      matching: find.byType(OutlinedButton),
    );
    expect(alreadyBrokenText, findsOneWidget);
    expect(alreadyBrokenButton, findsOneWidget);
    expect(
      tester.getCenter(alreadyBrokenText).dx,
      closeTo(tester.getCenter(alreadyBrokenButton).dx, 0.5),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });
}
