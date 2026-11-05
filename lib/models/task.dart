import 'package:flutter/material.dart' show TimeOfDay;

import '../utils/date_utils.dart';
import 'recurrence_rule.dart';
import 'subtask.dart';

class Task {
  final int? id;
  final String title;
  final String description;
  final DateTime dueDate; // date only (time part ignored)
  final TimeOfDay dueTime;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final bool isRepeating;

  // Not stored in the tasks table; loaded from other tables.
  final List<Subtask> subtasks;
  final RecurrenceRule? recurrence;

  const Task({
    this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    required this.dueTime,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    this.isRepeating = false,
    this.subtasks = const [],
    this.recurrence,
  });

  /// Due date and time combined (used for notifications and overdue check).
  DateTime get dueDateTime =>
      DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        dueTime.hour,
        dueTime.minute,
      );

  bool get isOverdue => !isCompleted && dueDateTime.isBefore(DateTime.now());

  /// Progress from 0.0 to 1.0. Example: 3 of 5 done -> 0.6 (60%).
  double get progress {
    if (subtasks.isEmpty) return isCompleted ? 1.0 : 0.0;
    final done = subtasks
        .where((s) => s.isCompleted)
        .length;
    return done / subtasks.length;
  }

  int get progressPercent => (progress * 100).round();

  Map<String, dynamic> toMap() =>
      {
        'id': id,
        'title': title,
        'description': description,
        'due_date': AppDateUtils.formatDate(dueDate),
        'due_time': AppDateUtils.formatTime(dueTime.hour, dueTime.minute),
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'is_repeating': isRepeating ? 1 : 0,
      };

  factory Task.fromMap(Map<String, dynamic> map, {
    List<Subtask> subtasks = const [],
    RecurrenceRule? recurrence,
  }) {
    final t = AppDateUtils.parseTime(map['due_time'] as String);
    final completed = map['completed_at'] as String?;
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      dueDate: AppDateUtils.parseDate(map['due_date'] as String),
      dueTime: TimeOfDay(hour: t[0], minute: t[1]),
      isCompleted: (map['is_completed'] as int) == 1,
      completedAt: completed == null ? null : DateTime.parse(completed),
      createdAt: DateTime.parse(map['created_at'] as String),
      isRepeating: (map['is_repeating'] as int) == 1,
      subtasks: subtasks,
      recurrence: recurrence,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    bool? isRepeating,
    List<Subtask>? subtasks,
    RecurrenceRule? recurrence,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        dueDate: dueDate ?? this.dueDate,
        dueTime: dueTime ?? this.dueTime,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: clearCompletedAt ? null : (completedAt ??
            this.completedAt),
        createdAt: createdAt ?? this.createdAt,
        isRepeating: isRepeating ?? this.isRepeating,
        subtasks: subtasks ?? this.subtasks,
        recurrence: recurrence ?? this.recurrence,
      );
}