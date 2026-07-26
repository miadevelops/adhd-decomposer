import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/routine.dart';
import '../../data/models/task.dart';
import '../../data/services/routine_service.dart';
import '../../data/services/siri_service.dart';
import '../providers/task_provider.dart';
import 'execute_screen.dart';

/// Minimum touch target size for accessibility
const double kMinTouchTarget = 48.0;

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text('Routines'),
        ),
        actions: [
          Semantics(
            label: 'Create new routine',
            button: true,
            excludeSemantics: true,
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Routine',
              onPressed: () => _createNewRoutine(context),
            ),
          ),
        ],
      ),
      body: Consumer<RoutineService>(
        builder: (context, routineService, _) {
          final routines = routineService.routines;
          final dueToday = routineService.routinesDueToday;
          final completedToday = routineService.routinesCompletedToday;
          
          if (routines.isEmpty) {
            return _buildEmptyState(context);
          }
          
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Streak celebration
              if (routineService.hasStreakCelebration)
                _buildStreakCelebration(context, routineService),
              
              // Due today section
              if (dueToday.isNotEmpty) ...[
                _buildSectionHeader(context, 'Due Today', Icons.today, Colors.orange),
                const SizedBox(height: 8),
                ...dueToday.map((r) => _RoutineCard(
                  routine: r,
                  onTap: () => _startRoutine(context, r),
                  onEdit: () => _editRoutine(context, r),
                  onDelete: () => _deleteRoutine(context, r),
                )),
                const SizedBox(height: 24),
              ],
              
              // Completed today section
              if (completedToday.isNotEmpty) ...[
                _buildSectionHeader(context, 'Completed Today', Icons.check_circle, 
                    Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                ...completedToday.map((r) => _RoutineCard(
                  routine: r,
                  isCompleted: true,
                  onTap: null,
                  onEdit: () => _editRoutine(context, r),
                  onDelete: () => _deleteRoutine(context, r),
                )),
                const SizedBox(height: 24),
              ],
              
              // All routines section (excluding already shown)
              _buildSectionHeader(context, 'All Routines', Icons.repeat, 
                  Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 8),
              ...routines
                  .where((r) => !dueToday.contains(r) && !completedToday.contains(r))
                  .map((r) => _RoutineCard(
                routine: r,
                onTap: () => _startRoutine(context, r),
                onEdit: () => _editRoutine(context, r),
                onDelete: () => _deleteRoutine(context, r),
              )),
              
              if (routines.every((r) => dueToday.contains(r) || completedToday.contains(r)))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'All routines are shown above',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: Semantics(
        label: 'Create new routine',
        button: true,
        excludeSemantics: true,
        child: FloatingActionButton.extended(
          onPressed: () => _createNewRoutine(context),
          icon: const Icon(Icons.add),
          label: const Text('New Routine'),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No routines yet',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create recurring routines to build healthy habits. '
              'Perfect for morning routines, daily check-ins, or weekly reviews.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _createNewRoutine(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Routine'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStreakCelebration(BuildContext context, RoutineService service) {
    final streakRoutines = service.celebratoryStreaks;
    final longestStreak = streakRoutines.isNotEmpty 
        ? streakRoutines.map((r) => r.completionStreak).reduce((a, b) => a > b ? a : b)
        : 0;
    
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amazing streak!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$longestStreak day streak! Keep it going!',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _createNewRoutine(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateRoutineScreen(),
      ),
    );
  }
  
  void _editRoutine(BuildContext context, Routine routine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateRoutineScreen(routineToEdit: routine),
      ),
    );
  }
  
  void _deleteRoutine(BuildContext context, Routine routine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Routine'),
        content: Text('Are you sure you want to delete "${routine.name}"? '
            'Your streak of ${routine.completionStreak} days will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<RoutineService>().deleteRoutine(routine.id);
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  void _startRoutine(BuildContext context, Routine routine) {
    final task = routine.toTask();
    context.read<TaskProvider>().addTask(task);
    context.read<TaskProvider>().setActiveTask(task);
    
    // Donate intent for Siri to suggest this routine next time
    SiriService().donateRoutineUsed(routine);
    
    // Navigate to execute screen with callback to mark routine complete
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExecuteScreen(
          onTaskComplete: () {
            context.read<RoutineService>().markRoutineComplete(routine.id);
          },
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final bool isCompleted;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.routine,
    this.isCompleted = false,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final streakText = routine.completionStreak > 0 
        ? '${routine.completionStreak} day streak' 
        : 'No streak yet';
    
    final semanticLabel = isCompleted
        ? 'Completed routine: ${routine.name}. ${routine.recurrenceDescription}. $streakText.'
        : 'Routine: ${routine.name}. ${routine.recurrenceDescription}. $streakText. '
          'Double tap to start.';
    
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isCompleted 
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
            : null,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showOptionsMenu(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        routine.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (routine.completionStreak >= 7)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              '${routine.completionStreak}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (routine.completionStreak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${routine.completionStreak} 🔥',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      routine.recurrenceDescription,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      routine.preferredTime.format(context),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${routine.totalEstimatedMinutes} min',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.checklist,
                      size: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${routine.steps.length} steps',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Routine'),
              onTap: () {
                Navigator.of(ctx).pop();
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen for creating or editing a routine
class CreateRoutineScreen extends StatefulWidget {
  final Routine? routineToEdit;
  final Task? taskToConvert;
  
  const CreateRoutineScreen({
    super.key,
    this.routineToEdit,
    this.taskToConvert,
  });

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  RecurrenceType _recurrence = RecurrenceType.daily;
  TimeOfDay _preferredTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _selectedDays = [1, 2, 3, 4, 5]; // Default to weekdays
  int _dayOfMonth = 1;
  List<TaskStep> _steps = [];
  
  bool get _isEditing => widget.routineToEdit != null;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.routineToEdit != null) {
      // Editing existing routine
      _nameController.text = widget.routineToEdit!.name;
      _recurrence = widget.routineToEdit!.recurrence;
      _preferredTime = widget.routineToEdit!.preferredTime;
      _selectedDays = List.from(widget.routineToEdit!.daysOfWeek);
      _dayOfMonth = widget.routineToEdit!.dayOfMonth ?? 1;
      _steps = List.from(widget.routineToEdit!.steps);
    } else if (widget.taskToConvert != null) {
      // Converting task to routine
      _nameController.text = widget.taskToConvert!.title;
      _steps = widget.taskToConvert!.steps.map((s) => TaskStep(
        id: s.id,
        action: s.action,
        estimatedMinutes: s.estimatedMinutes,
        subSteps: s.subSteps?.map((sub) => TaskStep(
          id: sub.id,
          action: sub.action,
          estimatedMinutes: sub.estimatedMinutes,
        )).toList(),
      )).toList();
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Routine' : 'Create Routine'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Routine Name',
                hintText: 'e.g., Morning routine',
                prefixIcon: Icon(Icons.edit),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            
            // Recurrence type
            Text(
              'Repeat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: RecurrenceType.values.map((type) {
                final isSelected = _recurrence == type;
                return ChoiceChip(
                  label: Text(_recurrenceLabel(type)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _recurrence = type);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            
            // Day selection for weekly
            if (_recurrence == RecurrenceType.weekly) ...[
              Text(
                'On which days?',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _dayChip(1, 'Mon'),
                  _dayChip(2, 'Tue'),
                  _dayChip(3, 'Wed'),
                  _dayChip(4, 'Thu'),
                  _dayChip(5, 'Fri'),
                  _dayChip(6, 'Sat'),
                  _dayChip(7, 'Sun'),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Day selection for monthly
            if (_recurrence == RecurrenceType.monthly) ...[
              Text(
                'Day of month',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _dayOfMonth,
                items: List.generate(31, (i) => i + 1)
                    .map((day) => DropdownMenuItem(
                          value: day,
                          child: Text('$day${_getOrdinalSuffix(day)}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _dayOfMonth = value);
                  }
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_month),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Preferred time
            Text(
              'Preferred Time',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(_preferredTime.format(context)),
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              onTap: _selectTime,
            ),
            const SizedBox(height: 24),
            
            // Steps section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Steps',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Step'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (_steps.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_list_numbered,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No steps yet',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _addStep,
                        child: const Text('Add First Step'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final step = _steps.removeAt(oldIndex);
                    _steps.insert(newIndex, step);
                  });
                },
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return _StepTile(
                    key: ValueKey(step.id),
                    step: step,
                    index: index,
                    onEdit: () => _editStep(index),
                    onDelete: () => _deleteStep(index),
                  );
                },
              ),
            
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveRoutine,
        icon: const Icon(Icons.save),
        label: Text(_isEditing ? 'Save Changes' : 'Create Routine'),
      ),
    );
  }
  
  Widget _dayChip(int day, String label) {
    final isSelected = _selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(day);
          } else {
            _selectedDays.remove(day);
          }
          _selectedDays.sort();
        });
      },
    );
  }
  
  String _recurrenceLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekdays:
        return 'Weekdays';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
    }
  }
  
  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
  
  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _preferredTime,
    );
    if (time != null) {
      setState(() => _preferredTime = time);
    }
  }
  
  void _addStep() {
    showDialog(
      context: context,
      builder: (ctx) => _StepDialog(
        onSave: (action, minutes) {
          setState(() {
            _steps.add(TaskStep(
              id: 'step_${DateTime.now().millisecondsSinceEpoch}',
              action: action,
              estimatedMinutes: minutes,
            ));
          });
        },
      ),
    );
  }
  
  void _editStep(int index) {
    final step = _steps[index];
    showDialog(
      context: context,
      builder: (ctx) => _StepDialog(
        initialAction: step.action,
        initialMinutes: step.estimatedMinutes,
        onSave: (action, minutes) {
          setState(() {
            _steps[index] = TaskStep(
              id: step.id,
              action: action,
              estimatedMinutes: minutes,
            );
          });
        },
      ),
    );
  }
  
  void _deleteStep(int index) {
    setState(() => _steps.removeAt(index));
  }
  
  void _saveRoutine() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one step')),
      );
      return;
    }
    
    if (_recurrence == RecurrenceType.weekly && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }
    
    final routineService = context.read<RoutineService>();
    
    if (_isEditing) {
      // Update existing routine
      final updated = widget.routineToEdit!.copyWith(
        name: _nameController.text,
        steps: _steps,
        recurrence: _recurrence,
        preferredTime: _preferredTime,
        daysOfWeek: _recurrence == RecurrenceType.weekly ? _selectedDays : [],
        dayOfMonth: _recurrence == RecurrenceType.monthly ? _dayOfMonth : null,
        totalEstimatedMinutes: _steps.fold<int>(0, (sum, s) => sum + s.estimatedMinutes),
      );
      routineService.updateRoutine(updated);
    } else {
      // Create new routine
      final routine = Routine(
        id: 'routine_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        steps: _steps,
        recurrence: _recurrence,
        preferredTime: _preferredTime,
        daysOfWeek: _recurrence == RecurrenceType.weekly ? _selectedDays : [],
        dayOfMonth: _recurrence == RecurrenceType.monthly ? _dayOfMonth : null,
      );
      routineService.addRoutine(routine);
    }
    
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Routine updated!' : 'Routine created!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final TaskStep step;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StepTile({
    super.key,
    required this.step,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('${index + 1}'),
        ),
        title: Text(step.action),
        subtitle: Text('${step.estimatedMinutes} min'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: onDelete,
            ),
            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }
}

class _StepDialog extends StatefulWidget {
  final String? initialAction;
  final int? initialMinutes;
  final Function(String action, int minutes) onSave;

  const _StepDialog({
    this.initialAction,
    this.initialMinutes,
    required this.onSave,
  });

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  final _actionController = TextEditingController();
  int _minutes = 5;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialAction != null) {
      _actionController.text = widget.initialAction!;
    }
    if (widget.initialMinutes != null) {
      _minutes = widget.initialMinutes!;
    }
  }
  
  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialAction != null ? 'Edit Step' : 'Add Step'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _actionController,
            decoration: const InputDecoration(
              labelText: 'What to do',
              hintText: 'e.g., Make bed',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Estimated time: '),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _minutes > 1 
                    ? () => setState(() => _minutes--) 
                    : null,
              ),
              Text('$_minutes min', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _minutes++),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_actionController.text.isNotEmpty) {
              widget.onSave(_actionController.text, _minutes);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
