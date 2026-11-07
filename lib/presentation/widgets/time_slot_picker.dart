import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../../data/services/calendar_service.dart';
import '../../data/models/task.dart';
import '../../core/theme/app_theme.dart';

/// Bottom sheet for picking a time slot to block for a task
class TimeSlotPicker extends StatefulWidget {
  final Task task;
  final CalendarService calendarService;
  final Function(DateTime) onTimeSelected;
  final VoidCallback? onQuickAdd;

  const TimeSlotPicker({
    super.key,
    required this.task,
    required this.calendarService,
    required this.onTimeSelected,
    this.onQuickAdd,
  });

  @override
  State<TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<TimeSlotPicker> {
  List<TimeSlot>? _suggestedSlots;
  bool _isLoading = true;
  TimeSlot? _selectedSlot;
  bool _useCustomTime = false;
  DateTime? _customDateTime;

  @override
  void initState() {
    super.initState();
    _loadSuggestedSlots();
  }

  Future<void> _loadSuggestedSlots() async {
    final now = DateTime.now();
    final duration = Duration(minutes: widget.task.totalEstimatedMinutes);
    // Search through 9 PM the day after tomorrow.
    final searchEnd = DateTime(
      now.year,
      now.month,
      now.day + 2,
      21,
    );

    List<TimeSlot> slots;
    try {
      slots = await widget.calendarService.findFreeSlots(
        duration,
        now,
        searchEnd,
        maxResults: 3,
      );
    } catch (e) {
      debugPrint('TimeSlotPicker: failed to load free slots: $e');
      slots = const [];
    }

    if (mounted) {
      setState(() {
        _suggestedSlots = slots;
        _isLoading = false;
        if (slots.isNotEmpty) {
          _selectedSlot = slots.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Semantics(
            header: true,
            child: Text(
              '📅 Block Time',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),

          // Task info
          Semantics(
            label:
                'Task: ${widget.task.title}. Duration: ${widget.task.totalEstimatedMinutes} minutes',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.task_alt_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '~${widget.task.totalEstimatedMinutes} min • ${widget.task.steps.length} steps',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Time slots
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _buildTimeSlotOptions(context),

          const SizedBox(height: 16),

          // Custom time option
          if (!_isLoading) _buildCustomTimeOption(context),

          const SizedBox(height: 24),

          // Action buttons
          _buildActionButtons(context),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
      ),
    );
  }

  Widget _buildTimeSlotOptions(BuildContext context) {
    if (_suggestedSlots == null || _suggestedSlots!.isEmpty) {
      return Semantics(
        label: 'No suggested time slots available. Use custom time instead.',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No suggested slots available.\nPick a custom time below.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Semantics(
      label: 'Suggested time slots',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested times',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...(_suggestedSlots!.map((slot) => _buildSlotOption(context, slot))),
        ],
      ),
    );
  }

  Widget _buildSlotOption(BuildContext context, TimeSlot slot) {
    final isSelected = !_useCustomTime && _selectedSlot == slot;

    return Semantics(
      label: 'Time slot: ${slot.label}',
      button: true,
      selected: isSelected,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedSlot = slot;
              _useCustomTime = false;
            });
            SemanticsService.announce(
                'Selected ${slot.label}', ui.TextDirection.ltr);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: const BoxConstraints(minHeight: kMinTouchTarget),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slot.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTimeOption(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or pick a custom time',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: _useCustomTime && _customDateTime != null
              ? 'Custom time: ${DateFormat('EEEE, MMM d • h:mm a').format(_customDateTime!)}'
              : 'Tap to pick a custom date and time',
          button: true,
          selected: _useCustomTime,
          child: InkWell(
            onTap: () => _showDateTimePicker(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(minHeight: kMinTouchTarget),
              decoration: BoxDecoration(
                color: _useCustomTime
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                border: Border.all(
                  color: _useCustomTime
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: _useCustomTime ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_calendar,
                    color: _useCustomTime
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _useCustomTime && _customDateTime != null
                          ? DateFormat('EEEE, MMM d • h:mm a')
                              .format(_customDateTime!)
                          : 'Pick date & time...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight:
                                _useCustomTime ? FontWeight.bold : FontWeight.normal,
                            color: _useCustomTime
                                ? null
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                          ),
                    ),
                  ),
                  if (_useCustomTime)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDateTimePicker(BuildContext context) async {
    final now = DateTime.now();

    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: _customDateTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'Pick a date for your task',
    );

    if (date == null || !context.mounted) return;

    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_customDateTime ?? now),
      helpText: 'Pick a start time',
    );

    if (time == null || !context.mounted) return;

    final selectedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (selectedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That time has already passed. Pick a later time.')),
      );
      return;
    }

    setState(() {
      _customDateTime = selectedDateTime;
      _useCustomTime = true;
    });

    SemanticsService.announce(
      'Selected ${DateFormat('EEEE, MMM d at h:mm a').format(selectedDateTime)}',
      ui.TextDirection.ltr,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final canConfirm =
        (!_useCustomTime && _selectedSlot != null) ||
        (_useCustomTime && _customDateTime != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick add button
        if (widget.onQuickAdd != null) ...[
          Semantics(
            label: 'Block next available hour',
            button: true,
            child: SizedBox(
              height: kMinTouchTarget,
              child: OutlinedButton.icon(
                onPressed: widget.onQuickAdd,
                icon: const Icon(Icons.bolt),
                label: const Text('Block next available hour'),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Confirm button
        Semantics(
          label: 'Add to calendar',
          button: true,
          enabled: canConfirm,
          child: SizedBox(
            height: kMinTouchTarget,
            child: ElevatedButton.icon(
              onPressed: canConfirm ? _confirmSelection : null,
              icon: const Icon(Icons.calendar_today),
              label: const Text('Add to Calendar'),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Cancel button
        Semantics(
          label: 'Cancel',
          button: true,
          child: SizedBox(
            height: kMinTouchTarget,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmSelection() {
    DateTime selectedTime;

    if (_useCustomTime && _customDateTime != null) {
      selectedTime = _customDateTime!;
    } else if (_selectedSlot != null) {
      selectedTime = _selectedSlot!.start;
    } else {
      return;
    }

    Navigator.of(context).pop();
    widget.onTimeSelected(selectedTime);
  }
}
