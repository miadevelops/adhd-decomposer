class Task {
  final String id;
  String title;
  List<TaskStep> steps;
  int totalEstimatedMinutes;
  DateTime createdAt;
  DateTime? completedAt;
  int currentStepIndex;
  int subStepBreakdownsUsed; // Track how many times user broke down steps

  Task({
    required this.id,
    required this.title,
    required this.steps,
    required this.totalEstimatedMinutes,
    required this.createdAt,
    this.completedAt,
    this.currentStepIndex = 0,
    this.subStepBreakdownsUsed = 0,
  });
  
  bool get isCompleted => completedAt != null;
  
  /// True when the task ended with every step skipped: it's closed, but
  /// nothing was actually done, so it shouldn't be celebrated or counted.
  bool get endedWithoutProgress => isCompleted && completedStepsCount == 0;

  int get completedStepsCount => steps.where((s) => s.isCompleted).length;
  
  double get progress => steps.isEmpty ? 0 : completedStepsCount / steps.length;

  TaskStep? get currentStep {
    if (currentStepIndex < steps.length) {
      return steps[currentStepIndex];
    }
    return null;
  }

  void completeCurrentStep() {
    if (currentStepIndex < steps.length) {
      final step = steps[currentStepIndex];
      
      // If step has substeps, complete the current substep first
      if (step.hasSubSteps && step.currentSubStep != null) {
        final allSubStepsDone = step.completeCurrentSubStep();
        if (!allSubStepsDone) {
          // More substeps to go, don't advance main step
          return;
        }
      }
      
      // All substeps done (or no substeps), complete the main step
      step.isCompleted = true;
      step.completedAt = DateTime.now();
      currentStepIndex++;
      
      if (currentStepIndex >= steps.length) {
        completedAt = DateTime.now();
      }
    }
  }

  void skipCurrentStep() {
    if (currentStepIndex < steps.length) {
      steps[currentStepIndex].isSkipped = true;
      currentStepIndex++;
      
      if (currentStepIndex >= steps.length) {
        completedAt = DateTime.now();
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'steps': steps.map((s) => s.toJson()).toList(),
    'totalEstimatedMinutes': totalEstimatedMinutes,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'currentStepIndex': currentStepIndex,
    'subStepBreakdownsUsed': subStepBreakdownsUsed,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    steps: (json['steps'] as List).map((s) => TaskStep.fromJson(s as Map<String, dynamic>)).toList(),
    totalEstimatedMinutes: json['totalEstimatedMinutes'],
    createdAt: DateTime.parse(json['createdAt']),
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    currentStepIndex: json['currentStepIndex'] ?? 0,
    subStepBreakdownsUsed: json['subStepBreakdownsUsed'] ?? 0,
  );
}

class TaskStep {
  final String id;
  String action;
  int estimatedMinutes;
  bool isCompleted;
  bool isSkipped;
  DateTime? completedAt;
  List<TaskStep>? subSteps;
  int currentSubStepIndex;

  TaskStep({
    required this.id,
    required this.action,
    required this.estimatedMinutes,
    this.isCompleted = false,
    this.isSkipped = false,
    this.completedAt,
    this.subSteps,
    this.currentSubStepIndex = 0,
  });
  
  /// Whether this step has been broken down into substeps
  bool get hasSubSteps => subSteps != null && subSteps!.isNotEmpty;
  
  /// Get current substep being worked on (if any)
  TaskStep? get currentSubStep {
    if (!hasSubSteps || currentSubStepIndex >= subSteps!.length) return null;
    return subSteps![currentSubStepIndex];
  }
  
  /// Number of completed substeps
  int get completedSubStepsCount => 
      subSteps?.where((s) => s.isCompleted).length ?? 0;
  
  /// Progress through substeps (0.0 to 1.0)
  double get subStepProgress => 
      hasSubSteps ? completedSubStepsCount / subSteps!.length : 0;
  
  /// Move to next substep, returns true if all substeps complete
  bool completeCurrentSubStep() {
    if (!hasSubSteps) return true;
    
    subSteps![currentSubStepIndex].isCompleted = true;
    subSteps![currentSubStepIndex].completedAt = DateTime.now();
    currentSubStepIndex++;
    
    return currentSubStepIndex >= subSteps!.length;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'estimatedMinutes': estimatedMinutes,
    'isCompleted': isCompleted,
    'isSkipped': isSkipped,
    'completedAt': completedAt?.toIso8601String(),
    'subSteps': subSteps?.map((s) => s.toJson()).toList(),
    'currentSubStepIndex': currentSubStepIndex,
  };

  factory TaskStep.fromJson(Map<String, dynamic> json) => TaskStep(
    id: json['id'] ?? '',
    action: json['action'],
    estimatedMinutes: json['estimatedMinutes'] ?? json['minutes'] ?? 5,
    isCompleted: json['isCompleted'] ?? false,
    isSkipped: json['isSkipped'] ?? false,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    subSteps: json['subSteps'] != null 
      ? (json['subSteps'] as List).map((s) => TaskStep.fromJson(s as Map<String, dynamic>)).toList()
      : null,
    currentSubStepIndex: json['currentSubStepIndex'] ?? 0,
  );
}
