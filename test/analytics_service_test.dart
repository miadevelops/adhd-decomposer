import 'package:adhd_decomposer/data/models/task.dart';
import 'package:adhd_decomposer/data/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task completion analytics accepts typed task steps', () {
    final task = Task(
      id: 'task-1',
      title: 'Test task',
      steps: [
        TaskStep(
          id: 'step-1',
          action: 'Finish this',
          estimatedMinutes: 1,
          isCompleted: true,
        ),
        TaskStep(
          id: 'step-2',
          action: 'Skip this',
          estimatedMinutes: 1,
          isSkipped: true,
        ),
      ],
      totalEstimatedMinutes: 2,
      createdAt: DateTime(2026),
    );

    expect(
      () => AnalyticsService.trackTaskCompleted(task),
      returnsNormally,
    );
  });
}
