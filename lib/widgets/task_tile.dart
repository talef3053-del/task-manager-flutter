import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import 'empty_state.dart';
import 'progress_bar.dart';

/// Colour used for completed tasks (mint green).
const Color _doneColor = Color(0xFF2BAE93);

/// A scrollable list of tasks with swipe-to-delete, used by every tab.
class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.tasks,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onOpen,
  });

  final List<Task> tasks;
  final IconData emptyIcon;
  final String emptyMessage;
  final void Function(Task task) onOpen;

  Future<bool> _confirmDelete(BuildContext context, Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Widget _swipeBackground(BuildContext context, Alignment align) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    alignment: align,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Icon(
      Icons.delete_rounded,
      color: Theme.of(context).colorScheme.onErrorContainer,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return EmptyState(icon: emptyIcon, message: emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final task = tasks[i];
        // Fade and slide in; later rows start slightly later.
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 250 + (i < 8 ? i : 8) * 40),
          curve: Curves.easeOut,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - v)),
              child: child,
            ),
          ),
          child: Dismissible(
            key: ValueKey(task.id),
            background: _swipeBackground(context, Alignment.centerLeft),
            secondaryBackground:
            _swipeBackground(context, Alignment.centerRight),
            confirmDismiss: (_) => _confirmDelete(context, task),
            onDismissed: (_) =>
                context.read<TaskProvider>().deleteTask(task.id!),
            child: TaskTile(task: task, onTap: () => onOpen(task)),
          ),
        );
      },
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  Future<void> _onCheck(BuildContext context) async {
    final provider = context.read<TaskProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final wasDone = task.isCompleted;

    await provider.toggleComplete(task);

    if (!wasDone) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('"${task.title}" completed'),
            action: SnackBarAction(
              label: 'Undo',
              // Pass a copy marked completed; toggling it marks it pending.
              onPressed: () =>
                  provider.toggleComplete(task.copyWith(isCompleted: true)),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final done = task.isCompleted;
    final overdue = task.isOverdue;
    final doneCount = task.subtasks.where((s) => s.isCompleted).length;

    // One colour decides the strip, checkbox, chips and card tint.
    final Color accent = done
        ? _doneColor
        : overdue
        ? scheme.error
        : scheme.primary;

    final cardColor =
    Color.alphaBlend(accent.withAlpha(isDark ? 30 : 18), scheme.surface);

    final dateText = '${DateFormat('EEE, d MMM').format(task.dueDate)}'
        ' • ${task.dueTime.format(context)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(isDark ? 20 : 40),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Coloured status strip
                  Container(width: 6, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CheckCircle(
                            checked: done,
                            color: accent,
                            onTap: () => _onCheck(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: done ? scheme.outline : null,
                                  ),
                                  child: Text(task.title),
                                ),
                                if (task.description.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      task.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                      theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _InfoPill(
                                      icon: Icons.schedule_rounded,
                                      text: dateText,
                                      color: accent,
                                    ),
                                    if (overdue)
                                      _InfoPill(
                                        icon: Icons.warning_amber_rounded,
                                        text: 'Overdue',
                                        color: scheme.error,
                                      ),
                                    if (task.recurrence != null ||
                                        task.isRepeating)
                                      _InfoPill(
                                        icon: Icons.repeat_rounded,
                                        text: task.recurrence?.label ??
                                            'Repeats',
                                        color: scheme.tertiary,
                                      ),
                                  ],
                                ),
                                if (task.subtasks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: TaskProgressBar(
                                      done: doneCount,
                                      total: task.subtasks.length,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round checkbox that fills and pops a tick when completed.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.checked,
    required this.color,
    required this.onTap,
  });

  final bool checked;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: AnimatedScale(
            scale: checked ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Small rounded label with an icon, e.g. "Mon, 9 Nov • 6:00 PM".
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}