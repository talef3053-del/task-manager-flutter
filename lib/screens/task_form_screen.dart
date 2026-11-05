import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/recurrence_rule.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/progress_bar.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task});

  /// null = add a new task, non-null = edit this task.
  final Task? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  final _subCtrl = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  late List<Subtask> _subtasks;
  bool _repeat = false;
  RepeatType _repeatType = RepeatType.daily;
  final Set<int> _weekdays = {};

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    final now = DateTime.now();
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _descCtrl = TextEditingController(text: t?.description ?? '');
    _date = t?.dueDate ?? DateTime(now.year, now.month, now.day);
    _time = t?.dueTime ?? TimeOfDay.now();
    _subtasks = List.of(t?.subtasks ?? const <Subtask>[]);

    final r = t?.recurrence;
    if (t != null && t.isRepeating && r != null) {
      _repeat = true;
      _repeatType = r.type;
      _weekdays.addAll(r.weekdays);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _addSubtask() {
    final text = _subCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      // taskId is replaced with the real id by the repository on save.
      _subtasks.add(Subtask(taskId: widget.task?.id ?? 0, title: text));
      _subCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_repeat && _repeatType == RepeatType.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one weekday')),
      );
      return;
    }

    _addSubtask(); // keep a half-typed subtask instead of losing it

    final provider = context.read<TaskProvider>();
    final old = widget.task;

    final recurrence = _repeat
        ? RecurrenceRule(
      id: old?.recurrence?.id,
      taskId: old?.id ?? 0,
      type: _repeatType,
      weekdays: _repeatType == RepeatType.weekly
          ? (_weekdays.toList()
        ..sort())
          : const [],
      // "This occurrence is the one for the chosen date", so the
      // engine will not reset it again on the same day.
      lastGeneratedDate: AppDateUtils.formatDate(_date),
    )
        : null;

    final task = Task(
      id: old?.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      dueDate: _date,
      dueTime: _time,
      isCompleted: old?.isCompleted ?? false,
      completedAt: old?.completedAt,
      createdAt: old?.createdAt ?? DateTime.now(),
      isRepeating: _repeat,
      subtasks: _subtasks,
      recurrence: recurrence,
    );

    if (old == null) {
      await provider.addTask(task);
    } else {
      await provider.updateTask(task);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _subtasks
        .where((s) => s.isCompleted)
        .length;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit task' : 'New task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
              (v == null || v
                  .trim()
                  .isEmpty)
                  ? 'Please enter a title'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('EEE, d MMM y').format(_date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),

            // ---------- Subtasks (Phase 4) ----------
            const SizedBox(height: 24),
            Text('Subtasks', style: Theme
                .of(context)
                .textTheme
                .titleMedium),
            const SizedBox(height: 8),
            if (_subtasks.isNotEmpty)
              TaskProgressBar(done: doneCount, total: _subtasks.length),
            for (var i = 0; i < _subtasks.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: _subtasks[i].isCompleted,
                  onChanged: (v) =>
                      setState(() =>
                      _subtasks[i] = _subtasks[i].copyWith(isCompleted: v)),
                ),
                title: Text(
                  _subtasks[i].title,
                  style: TextStyle(
                    decoration: _subtasks[i].isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove subtask',
                  onPressed: () => setState(() => _subtasks.removeAt(i)),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add a subtask',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Add subtask',
                  onPressed: _addSubtask,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            // ---------- Repeat (Phase 5) ----------
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repeat this task'),
              value: _repeat,
              onChanged: (v) => setState(() => _repeat = v),
            ),
            if (_repeat) ...[
              SegmentedButton<RepeatType>(
                segments: const [
                  ButtonSegment(value: RepeatType.daily, label: Text('Daily')),
                  ButtonSegment(
                      value: RepeatType.weekly, label: Text('Weekly')),
                ],
                selected: {_repeatType},
                onSelectionChanged: (s) =>
                    setState(() => _repeatType = s.first),
              ),
              if (_repeatType == RepeatType.weekly) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(_dayNames[d - 1]),
                        selected: _weekdays.contains(d),
                        onSelected: (v) =>
                            setState(() {
                              if (v) {
                                _weekdays.add(d);
                              } else {
                                _weekdays.remove(d);
                              }
                            }),
                      ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Add task'),
            ),
          ],
        ),
      ),
    );
  }
}