import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/coach.dart';
import '../coaches.dart';
import 'backend_service.dart';

// Re-export for convenience
export 'backend_service.dart' show RateLimitException, UsageStats, SubStepsResult;

/// Where the most recent AI result came from.
enum AIResultSource {
  /// Tiny Steps backend (counts against the free allowance)
  backend,
  /// User's own OpenAI key
  customKey,
  /// Built-in offline templates (never counts against the free allowance)
  offline,
}

/// Decomposition style modes for different user needs
enum DecompositionStyle {
  /// Standard mode - balanced detail and encouragement
  standard,
  /// Quick mode - fewer steps, faster completion for time pressure
  quick,
  /// Gentle mode - extra supportive language for bad brain days
  gentle,
}

class AIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  final String? defaultApiKey;
  final Uuid _uuid = const Uuid();
  final BackendService _backend;

  /// Source of the last result returned by [decomposeTask] or [getSubSteps].
  AIResultSource lastSource = AIResultSource.offline;

  /// Server-reported usage from the last backend call, if any.
  UsageStats? lastUsage;
  
  AIService({this.defaultApiKey, BackendService? backend})
      : _backend = backend ?? BackendService();
  
  /// Decompose a task into manageable steps
  /// 
  /// [taskDescription] - The task to break down
  /// [apiKey] - Optional API key override (for BYOK, currently disabled)
  /// [style] - Decomposition style (standard, quick, gentle)
  /// [currentHour] - Current hour (0-23) for time-aware prompting
  /// [coach] - Optional coach personality for tone/style
  Future<Task> decomposeTask(
    String taskDescription, {
    String? apiKey,
    DecompositionStyle style = DecompositionStyle.standard,
    int? currentHour,
    Coach? coach,
  }) async {
    final effectiveCoach = coach ?? Coaches.default_;
    
    // Try backend first
    try {
      final result = await _backend.decomposeTask(taskDescription, style: style);
      if (result != null && result['success'] == true && result['task'] != null) {
        final task = _parseBackendResponse(result);
        lastSource = AIResultSource.backend;
        lastUsage = result['_usage'] as UsageStats?;
        return task;
      }
    } on RateLimitException {
      rethrow; // Let the UI handle rate limiting
    } catch (e) {
      // Backend failed, continue to fallback
    }
    
    // Fallback: Use custom API key if provided (BYOK - currently hidden)
    final effectiveKey = apiKey ?? defaultApiKey;
    final hour = currentHour ?? DateTime.now().hour;
    
    if (effectiveKey != null && effectiveKey.isNotEmpty) {
      try {
        final systemPrompt = _buildSystemPrompt(taskDescription, style, hour, effectiveCoach);
        final userPrompt = _buildUserPrompt(taskDescription, style);
        
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $effectiveKey',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': style == DecompositionStyle.quick ? 0.5 : 0.7,
            'max_tokens': style == DecompositionStyle.quick ? 600 : 1200,
          }),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content = data['choices'][0]['message']['content'];
          final task = _parseAIResponse(taskDescription, content);
          lastSource = AIResultSource.customKey;
          return task;
        }
      } catch (e) {
        // BYOK failed, continue to mock
      }
    }
    
    // Final fallback: offline templates
    lastSource = AIResultSource.offline;
    return _getMockDecomposition(taskDescription, style: style);
  }
  
  /// Parse response from our backend API
  Task _parseBackendResponse(Map<String, dynamic> result) {
    final taskData = result['task'] as Map<String, dynamic>;
    final rawSteps = taskData['steps'] as List;
    
    final steps = rawSteps.map((s) {
      if (s is Map<String, dynamic>) {
        return TaskStep(
          id: _uuid.v4(),
          action: (s['action'] as String?) ?? '',
          estimatedMinutes: (s['estimatedMinutes'] as int?) ?? 5,
        );
      }
      // Fallback for plain string steps
      return TaskStep(
        id: _uuid.v4(),
        action: s.toString(),
        estimatedMinutes: 5,
      );
    }).toList();
    
    final totalMinutes = (taskData['totalEstimatedMinutes'] as int?) ??
        steps.fold<int>(0, (sum, s) => sum + s.estimatedMinutes);
    
    return Task(
      id: _uuid.v4(),
      title: (taskData['title'] as String?) ?? 'Task',
      steps: steps,
      totalEstimatedMinutes: totalMinutes,
      createdAt: DateTime.now(),
    );
  }
  
  /// Get usage stats from backend
  Future<UsageStats?> getUsageStats() async {
    return _backend.getUsage();
  }
  
  /// Verify subscription with backend
  Future<bool> verifySubscription({required String revenueCatUserId}) async {
    return _backend.verifySubscription(revenueCatUserId: revenueCatUserId);
  }
  
  /// Get smaller sub-steps when user is stuck
  /// 
  /// [stepAction] - The step they're stuck on
  /// [apiKey] - Optional API key (for BYOK, currently disabled)
  /// [taskContext] - Optional context about the overall task
  Future<List<TaskStep>> getSubSteps(
    String stepAction,
    String? apiKey, {
    String? taskContext,
  }) async {
    // Try backend first
    try {
      final result = await _backend.getSubSteps(stepAction, taskContext: taskContext);
      if (result != null && result.substeps.isNotEmpty) {
        lastSource = AIResultSource.backend;
        lastUsage = result.usage;
        return result.substeps.map((s) => TaskStep(
          id: _uuid.v4(),
          action: s,
          estimatedMinutes: 2,
        )).toList();
      }
    } on RateLimitException {
      rethrow;
    } catch (e) {
      // Backend failed, continue to fallback
    }
    
    // Fallback to offline templates
    lastSource = AIResultSource.offline;
    return _getMockSubSteps(stepAction);
  }
  
  /// Build the system prompt based on context
  String _buildSystemPrompt(String task, DecompositionStyle style, int hour, Coach coach) {
    final taskType = _detectTaskType(task);
    final timeContext = _getTimeContext(hour);
    final mentionsADHD = task.toLowerCase().contains('adhd');
    
    final basePrompt = StringBuffer();
    
    // Style-specific opening
    switch (style) {
      case DecompositionStyle.quick:
        basePrompt.writeln(_quickModePrompt);
        break;
      case DecompositionStyle.gentle:
        basePrompt.writeln(_gentleModePrompt);
        break;
      case DecompositionStyle.standard:
        basePrompt.writeln(_standardModePrompt);
        break;
    }
    
    // Add coach personality
    basePrompt.writeln('\n--- COACH PERSONALITY ---');
    basePrompt.writeln('You are the "${coach.name}" coach. Your tagline: "${coach.tagline}"');
    basePrompt.writeln(coach.promptStyle);
    basePrompt.writeln('--- END COACH PERSONALITY ---');
    
    // Add context-aware elements
    if (taskType != null) {
      basePrompt.writeln('\n$taskType');
    }
    
    if (timeContext != null) {
      basePrompt.writeln('\n$timeContext');
    }
    
    if (mentionsADHD) {
      basePrompt.writeln('\n$_adhdAcknowledgment');
    }
    
    // Add step quality guidelines
    if (style != DecompositionStyle.quick) {
      basePrompt.writeln('\n$_stepQualityGuidelines');
    }
    
    basePrompt.writeln('\n$_outputFormat');
    
    return basePrompt.toString();
  }
  
  /// Build the user prompt
  String _buildUserPrompt(String task, DecompositionStyle style) {
    switch (style) {
      case DecompositionStyle.quick:
        return 'Quick breakdown needed: "$task"';
      case DecompositionStyle.gentle:
        return 'Please help me break down this task gently: "$task"';
      case DecompositionStyle.standard:
        return 'Break down this task: "$task"';
    }
  }
  
  /// Detect the type of task for context-aware prompting
  String? _detectTaskType(String task) {
    final lower = task.toLowerCase();
    
    // Cleaning tasks
    if (_matchesAny(lower, ['clean', 'tidy', 'organize', 'declutter', 'wash', 'vacuum', 'mop', 'dust'])) {
      return _cleaningContext;
    }
    
    // Work/productivity tasks
    if (_matchesAny(lower, ['email', 'report', 'meeting', 'presentation', 'deadline', 'project', 'work', 'write', 'document'])) {
      return _workContext;
    }
    
    // Errands
    if (_matchesAny(lower, ['grocery', 'shopping', 'store', 'errand', 'pick up', 'drop off', 'appointment', 'pharmacy', 'bank'])) {
      return _errandsContext;
    }
    
    // Self-care
    if (_matchesAny(lower, ['shower', 'brush', 'exercise', 'workout', 'eat', 'meal', 'sleep', 'bed', 'routine', 'hygiene'])) {
      return _selfCareContext;
    }
    
    // Administrative/paperwork
    if (_matchesAny(lower, ['tax', 'bill', 'form', 'paperwork', 'application', 'insurance', 'budget', 'finance'])) {
      return _adminContext;
    }
    
    return null;
  }
  
  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
  
  /// Get time-of-day context for the prompt
  String? _getTimeContext(int hour) {
    if (hour >= 5 && hour < 10) {
      return _morningContext;
    } else if (hour >= 10 && hour < 14) {
      return _middayContext;
    } else if (hour >= 14 && hour < 18) {
      return _afternoonContext;
    } else if (hour >= 18 && hour < 22) {
      return _eveningContext;
    } else {
      return _lateNightContext;
    }
  }
  
  Task _parseAIResponse(String originalTask, String content) {
    try {
      // Try to parse JSON from the response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        
        final steps = (json['steps'] as List).map((step) {
          return TaskStep(
            id: _uuid.v4(),
            action: step['action'] ?? step['step'] ?? '',
            estimatedMinutes: step['minutes'] ?? step['estimatedMinutes'] ?? 5,
          );
        }).toList();
        
        return Task(
          id: _uuid.v4(),
          title: json['task_name'] ?? json['taskName'] ?? originalTask,
          steps: steps,
          totalEstimatedMinutes: json['total_estimated_minutes'] ?? 
                                 json['totalEstimatedMinutes'] ?? 
                                 steps.fold(0, (sum, s) => sum + s.estimatedMinutes),
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      // If parsing fails, return mock
    }
    return _getMockDecomposition(originalTask);
  }
  
  Task _getMockDecomposition(String taskDescription, {DecompositionStyle style = DecompositionStyle.standard}) {
    // Intelligent mock based on common tasks
    final lowerTask = taskDescription.toLowerCase();
    
    List<Map<String, dynamic>> mockSteps;
    
    if (lowerTask.contains('clean') && lowerTask.contains('kitchen')) {
      mockSteps = style == DecompositionStyle.quick
          ? [
              {'action': 'Clear countertops into sink', 'minutes': 3},
              {'action': 'Load dishwasher and start it', 'minutes': 5},
              {'action': 'Wipe counters and stovetop', 'minutes': 5},
              {'action': 'Quick floor sweep', 'minutes': 3},
            ]
          : style == DecompositionStyle.gentle
          ? [
              {'action': '💭 Take a breath. Walk to the kitchen doorway and just look around', 'minutes': 1},
              {'action': '🫧 Clear the countertop closest to you - just that one spot first', 'minutes': 3},
              {'action': '🌟 Nice! Now put away anything that doesn\'t belong in the kitchen', 'minutes': 3},
              {'action': '🍽️ Load dishes into dishwasher. You can do this while sitting if needed!', 'minutes': 5},
              {'action': '✨ Reward moment: Get yourself a drink or snack', 'minutes': 2},
              {'action': '🧽 Wipe down the counters - feel how smooth they become', 'minutes': 4},
              {'action': '🔥 Clean the stovetop - watch it transform', 'minutes': 3},
              {'action': '🧹 Quick sweep or spot-clean the floor', 'minutes': 4},
              {'action': '🎉 Done! Look at what you accomplished!', 'minutes': 1},
            ]
          : [
              {'action': 'Walk to the kitchen and take a quick look around', 'minutes': 1},
              {'action': 'Clear countertops - put items in sink or trash', 'minutes': 3},
              {'action': 'Put away any items that belong elsewhere', 'minutes': 2},
              {'action': 'Load dirty dishes into dishwasher', 'minutes': 5},
              {'action': 'Hand wash any remaining dishes', 'minutes': 5},
              {'action': 'Wipe down countertops with cloth', 'minutes': 3},
              {'action': 'Wipe stovetop and appliance fronts', 'minutes': 3},
              {'action': 'Take out trash if it\'s getting full', 'minutes': 2},
              {'action': 'Sweep or wipe down the floor', 'minutes': 5},
            ];
    } else if (lowerTask.contains('laundry')) {
      mockSteps = style == DecompositionStyle.quick
          ? [
              {'action': 'Gather dirty clothes into basket', 'minutes': 3},
              {'action': 'Load washer and start cycle', 'minutes': 3},
              {'action': 'Set phone timer for cycle end', 'minutes': 1},
              {'action': 'Transfer to dryer when timer rings', 'minutes': 2},
            ]
          : style == DecompositionStyle.gentle
          ? [
              {'action': '🧺 Grab the laundry basket. Just holding it is progress!', 'minutes': 1},
              {'action': '👕 Walk around and toss clothes in. No folding, just gathering', 'minutes': 4},
              {'action': '🚶 Carry basket to the washing machine - feel the weight decrease', 'minutes': 2},
              {'action': '🌀 Load clothes in gently. Add detergent. Press start', 'minutes': 3},
              {'action': '📱 Set a timer and give yourself permission to relax until it goes off', 'minutes': 1},
              {'action': '✨ When done: Transfer to dryer. The warm clothes feel nice!', 'minutes': 3},
              {'action': '👚 Fold while watching something comforting. No rush', 'minutes': 15},
              {'action': '🏠 Put away one category at a time. Celebrate each drawer!', 'minutes': 5},
            ]
          : [
              {'action': 'Grab laundry basket from your room', 'minutes': 1},
              {'action': 'Gather all dirty clothes into basket', 'minutes': 5},
              {'action': 'Sort clothes by color/type if needed', 'minutes': 3},
              {'action': 'Load first batch into washer', 'minutes': 2},
              {'action': 'Add detergent and start cycle', 'minutes': 1},
              {'action': 'Set timer for when cycle ends', 'minutes': 1},
              {'action': 'Transfer to dryer when done', 'minutes': 2},
              {'action': 'Fold clothes when dry', 'minutes': 10},
              {'action': 'Put folded clothes away', 'minutes': 5},
            ];
    } else if (lowerTask.contains('email') || lowerTask.contains('inbox')) {
      mockSteps = style == DecompositionStyle.quick
          ? [
              {'action': 'Open inbox and delete spam', 'minutes': 2},
              {'action': 'Reply to urgent emails only', 'minutes': 5},
              {'action': 'Archive everything else for later', 'minutes': 2},
            ]
          : style == DecompositionStyle.gentle
          ? [
              {'action': '💻 Open your email. Just opening it is the hard part', 'minutes': 1},
              {'action': '🗑️ Delete obvious spam first - easy wins', 'minutes': 2},
              {'action': '⭐ Star the emails that feel scary - we\'ll handle them', 'minutes': 2},
              {'action': '💬 Reply to ONE easy email. Just one!', 'minutes': 3},
              {'action': '☕ Take a sip of water or tea. You\'re doing great', 'minutes': 1},
              {'action': '📧 Reply to one more email - still an easy one', 'minutes': 3},
              {'action': '📦 Archive everything you\'ve handled', 'minutes': 2},
              {'action': '⭐ Look at those starred emails. Pick the least scary one', 'minutes': 5},
              {'action': '🎉 Close inbox and celebrate! More tomorrow is okay', 'minutes': 1},
            ]
          : [
              {'action': 'Open email app/website', 'minutes': 1},
              {'action': 'Delete obvious spam and junk', 'minutes': 2},
              {'action': 'Flag emails that need action later', 'minutes': 3},
              {'action': 'Reply to quick emails (under 2 min each)', 'minutes': 5},
              {'action': 'Archive handled emails', 'minutes': 2},
              {'action': 'Tackle one flagged email', 'minutes': 5},
            ];
    } else {
      // Generic decomposition
      mockSteps = style == DecompositionStyle.quick
          ? [
              {'action': 'Gather what you need', 'minutes': 2},
              {'action': 'Do the main task', 'minutes': 10},
              {'action': 'Clean up and done', 'minutes': 3},
            ]
          : style == DecompositionStyle.gentle
          ? [
              {'action': '🌟 First, just stand up or sit up straight. You\'re starting!', 'minutes': 1},
              {'action': '🔍 Look at what you need for this task. Just look, no action yet', 'minutes': 1},
              {'action': '🎯 Gather one item you\'ll need', 'minutes': 2},
              {'action': '✨ Good! Get the rest of your materials', 'minutes': 2},
              {'action': '🌱 Start with the easiest, smallest part', 'minutes': 5},
              {'action': '☕ Mini break - stretch or take a sip of water', 'minutes': 1},
              {'action': '💪 Continue with the next small piece', 'minutes': 5},
              {'action': '🎨 Keep going - you\'re in the flow now', 'minutes': 5},
              {'action': '🧹 Start putting things away as you finish', 'minutes': 3},
              {'action': '🎉 Done! Take a moment to appreciate what you did', 'minutes': 1},
            ]
          : [
              {'action': 'Get materials/tools needed for task', 'minutes': 3},
              {'action': 'Set up your workspace', 'minutes': 2},
              {'action': 'Start with the easiest part first', 'minutes': 5},
              {'action': 'Continue to the next section', 'minutes': 5},
              {'action': 'Take a quick stretch break', 'minutes': 1},
              {'action': 'Complete the remaining work', 'minutes': 5},
              {'action': 'Clean up and put things away', 'minutes': 3},
            ];
    }
    
    final steps = mockSteps.map((s) => TaskStep(
      id: _uuid.v4(),
      action: s['action'],
      estimatedMinutes: s['minutes'],
    )).toList();
    
    return Task(
      id: _uuid.v4(),
      title: taskDescription,
      steps: steps,
      totalEstimatedMinutes: steps.fold(0, (sum, s) => sum + s.estimatedMinutes),
      createdAt: DateTime.now(),
    );
  }
  
  List<TaskStep> _getMockSubSteps(String stepAction) {
    // Generate contextual sub-steps based on the original step
    final lowerStep = stepAction.toLowerCase();
    
    // Detect step type and provide contextual breakdown
    if (lowerStep.contains('email') || lowerStep.contains('message') || lowerStep.contains('write')) {
      return [
        TaskStep(
          id: _uuid.v4(),
          action: '📱 Open the app/website where you need to write',
          estimatedMinutes: 1,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '✏️ Type just the first sentence - anything counts',
          estimatedMinutes: 2,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '📝 Add 1-2 more sentences (that\'s enough!)',
          estimatedMinutes: 2,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '✅ Quick read and hit send/save',
          estimatedMinutes: 1,
        ),
      ];
    } else if (lowerStep.contains('clean') || lowerStep.contains('tidy') || lowerStep.contains('organize')) {
      return [
        TaskStep(
          id: _uuid.v4(),
          action: '🧺 Grab ONE item that\'s in the wrong place',
          estimatedMinutes: 1,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '🚶 Walk it to where it belongs',
          estimatedMinutes: 1,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '🔄 Repeat for 3 more items (just 3!)',
          estimatedMinutes: 3,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '✨ Do one quick wipe of the nearest surface',
          estimatedMinutes: 2,
        ),
      ];
    } else if (lowerStep.contains('call') || lowerStep.contains('phone')) {
      return [
        TaskStep(
          id: _uuid.v4(),
          action: '📱 Open your phone and find the contact',
          estimatedMinutes: 1,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '📝 Jot down 2-3 bullet points of what to say',
          estimatedMinutes: 2,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '☎️ Press call (you can do this!)',
          estimatedMinutes: 1,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '🗣️ Say hi and follow your bullet points',
          estimatedMinutes: 3,
        ),
      ];
    } else {
      // Generic breakdown for any step
      return [
        TaskStep(
          id: _uuid.v4(),
          action: '🌬️ Take a deep breath - you\'ve got this',
          estimatedMinutes: 1,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '🦶 Stand up and move to where you need to be',
          estimatedMinutes: 1,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '👆 Touch/grab the first thing needed for: $stepAction',
          estimatedMinutes: 1,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '⏱️ Do just 2 minutes of: $stepAction',
          estimatedMinutes: 2,
        ),
        TaskStep(
          id: _uuid.v4(),
          action: '✅ Keep going or mark done - both are wins!',
          estimatedMinutes: 1,
        ),
      ];
    }
  }

  // ============================================
  // PROMPT TEMPLATES
  // ============================================
  
  static const String _standardModePrompt = '''
You are a supportive ADHD-friendly task assistant. Break down tasks into small, actionable steps that each take 2-10 minutes.

Core principles:
- Each step should be ONE clear physical action
- Use simple, direct language starting with action verbs (Put, Open, Grab, Walk, Type)
- NO "think about" or "consider" steps - only concrete actions
- Include realistic time estimates
- Be encouraging but authentic - no toxic positivity
- Maximum 10 steps, minimum 3 steps''';

  static const String _quickModePrompt = '''
You are a fast-paced task assistant. The user is pressed for time. Give them the MINIMUM viable steps to complete this task.

Rules:
- Maximum 5 steps
- Only essential actions - skip setup/cleanup unless critical
- Brief, action-focused language
- No fluff, no encouragement text
- Focus on: What's the fastest path to "done"?''';

  static const String _gentleModePrompt = '''
You are a warm, understanding task assistant for someone having a tough brain day. Your tone is like a supportive friend who gets it.

Core principles:
- Start with the smallest possible action (even just standing up)
- Use emojis sparingly but warmly (1-2 per step max)
- Include sensory details to help with body doubling ("feel the warm water", "hear the click")
- Add brief "reward yourself" micro-moments every 3-4 steps
- Acknowledge that starting is the hardest part
- Use phrases like "just this one thing" and "you can stop after this if you need to"
- Include grounding moments (noticing breath, feeling feet on floor)
- Maximum 12 steps to avoid overwhelm''';

  // Context-specific guidance
  static const String _cleaningContext = '''
Task type detected: CLEANING
- Include transition cues ("Now that you're at the sink...")
- Reference sensory satisfaction (shiny surfaces, clear counters)
- Suggest background audio/podcast for body doubling
- Break into zones/areas for spatial clarity''';

  static const String _workContext = '''
Task type detected: WORK/PRODUCTIVITY
- Minimize decision points - be specific
- Include "close other tabs/apps" as a step if relevant
- Suggest time-boxing ("spend just 5 minutes on...")
- Include one "just start typing anything" step for writing tasks''';

  static const String _errandsContext = '''
Task type detected: ERRANDS
- List exactly what to bring (keys, wallet, list)
- Include "check if you have X" steps
- Group by location to minimize trips
- Include realistic travel/parking time''';

  static const String _selfCareContext = '''
Task type detected: SELF-CARE
- Extra gentle, no judgment
- Include sensory comfort details
- Acknowledge that basic tasks can be hard
- Suggest pairing with something enjoyable (music, podcast)''';

  static const String _adminContext = '''
Task type detected: ADMINISTRATIVE/PAPERWORK
- Break down into "gather documents" first
- Include specific what-to-look-for details
- Suggest a reward after completion
- Acknowledge that paperwork is tedious for most people''';

  // Time-of-day contexts
  static const String _morningContext = '''
Time context: MORNING
- Account for possible grogginess
- Include hydration/caffeine step if appropriate
- Gentler pacing for first tasks
- "Morning momentum" - start with one easy win''';

  static const String _middayContext = '''
Time context: MIDDAY
- Energy may be at peak - can suggest slightly more complex sequences
- Include lunch/snack break reminder if task is long
- Good time for focused work tasks''';

  static const String _afternoonContext = '''
Time context: AFTERNOON
- Energy may be dipping
- Include stretch/movement breaks
- Shorter task segments
- Consider post-lunch slump''';

  static const String _eveningContext = '''
Time context: EVENING
- Wind-down energy
- Shorter, lighter steps
- Include relaxation angle where possible
- Acknowledge end-of-day tiredness''';

  static const String _lateNightContext = '''
Time context: LATE NIGHT
- Very gentle approach
- Question if task can wait until tomorrow
- If urgent, minimal essential steps only
- Include "get ready for sleep soon" awareness''';

  static const String _adhdAcknowledgment = '''
The user mentioned ADHD in their task. Acknowledge their experience:
- You understand that starting is often the hardest part
- Executive dysfunction is real and valid
- Small steps are not "cheating" - they're smart strategy
- Include one "just do 10 seconds" option for the hardest step''';

  static const String _stepQualityGuidelines = '''
Step quality guidelines:
- Add transition cues between steps when changing location or tool ("Now that you're at the desk...")
- Include sensory details for body doubling ("Feel the keyboard under your fingers")
- Every 4-5 steps, include a mini-reward or grounding moment ("Take a breath and notice how far you've come")
- Make the first step almost impossibly easy - this breaks initiation paralysis''';

  static const String _outputFormat = '''
Output format (JSON only, no explanation before or after):
{
  "task_name": "Clean the kitchen",
  "total_estimated_minutes": 28,
  "steps": [
    {"action": "Walk to the kitchen doorway and take a look around", "minutes": 1},
    {"action": "Put all dishes in sink", "minutes": 3}
  ]
}''';
}
