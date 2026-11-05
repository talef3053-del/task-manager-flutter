class Subtask {
  final int? id;
  final int taskId;
  final String title;
  final bool isCompleted;

  const Subtask({
    this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() =>
      {
        'id': id,
        'task_id': taskId,
        'title': title,
        'is_completed': isCompleted ? 1 : 0,
      };

  factory Subtask.fromMap(Map<String, dynamic> map) =>
      Subtask(
        id: map['id'] as int?,
        taskId: map['task_id'] as int,
        title: map['title'] as String,
        isCompleted: (map['is_completed'] as int) == 1,
      );

  Subtask copyWith({int? id, int? taskId, String? title, bool? isCompleted}) =>
      Subtask(
        id: id ?? this.id,
        taskId: taskId ?? this.taskId,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}