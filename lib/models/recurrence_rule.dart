enum RepeatType { daily, weekly }

class RecurrenceRule {
  final int? id;
  final int taskId;
  final RepeatType type;

  /// Weekdays the task repeats on. Monday = 1 ... Sunday = 7
  /// (same numbering as DateTime.weekday). Ignored for daily rules.
  final List<int> weekdays;

  /// Last day the task was reset/generated. Prevents duplicates.
  final String? lastGeneratedDate;

  /// Human-readable text such as "Every day" or "Mon, Wed, Fri".
  String get label {
    if (type == RepeatType.daily) return 'Every day';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = [...weekdays]..sort();
    return days.map((d) => names[d - 1]).join(', ');
  }
  const RecurrenceRule({
    this.id,
    required this.taskId,
    required this.type,
    this.weekdays = const [],
    this.lastGeneratedDate,
  });

  /// Does this rule apply on the given date?
  bool appliesOn(DateTime date) {
    if (type == RepeatType.daily) return true;
    return weekdays.contains(date.weekday);
  }

  Map<String, dynamic> toMap() =>
      {
        'id': id,
        'task_id': taskId,
        'repeat_type': type.name,
        'weekdays': weekdays.join(','),
        'last_generated_date': lastGeneratedDate,
      };

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    final raw = (map['weekdays'] as String?) ?? '';
    return RecurrenceRule(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      type: RepeatType.values.byName(map['repeat_type'] as String),
      weekdays: raw.isEmpty
          ? <int>[]
          : raw.split(',').map((e) => int.parse(e)).toList(),
      lastGeneratedDate: map['last_generated_date'] as String?,
    );
  }

  RecurrenceRule copyWith({
    int? id,
    int? taskId,
    RepeatType? type,
    List<int>? weekdays,
    String? lastGeneratedDate,
  }) =>
      RecurrenceRule(
        id: id ?? this.id,
        taskId: taskId ?? this.taskId,
        type: type ?? this.type,
        weekdays: weekdays ?? this.weekdays,
        lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      );
}