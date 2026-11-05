import '../services/notification_service.dart';
import '../services/recurrence_service.dart';
import 'package:flutter/foundation.dart';

import '../database/task_repository.dart';
import '../models/task.dart';

enum TaskFilter { all, overdue, repeating }

/// Holds the task list for the UI. Every change goes
/// repository -> reload -> notifyListeners().
class TaskProvider extends ChangeNotifier {
  TaskProvider({TaskRepository? repository})
      : _repo = repository ?? TaskRepository() {
    _recurrence = RecurrenceService(_repo);
  }

  final TaskRepository _repo;
  late final RecurrenceService _recurrence;

  List<Task> _tasks = [];
  bool _isLoading = false;
  String _query = '';
  TaskFilter _filter = TaskFilter.all;

  bool get isLoading => _isLoading;
  /// Every task, unfiltered. Used by the export feature.
  List<Task> get allTasks => List.unmodifiable(_tasks);

  String get query => _query;

  TaskFilter get filter => _filter;

  bool get hasActiveSearchOrFilter =>
      _query
          .trim()
          .isNotEmpty || _filter != TaskFilter.all;

  // ---------- Search and filter ----------

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setFilter(TaskFilter value) {
    _filter = value;
    notifyListeners();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _matchesSearch(Task t) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.title.toLowerCase().contains(q) ||
        t.description.toLowerCase().contains(q);
  }

  bool _matchesFilter(Task t) =>
      switch (_filter) {
        TaskFilter.all => true,
        TaskFilter.overdue => t.isOverdue,
        TaskFilter.repeating => t.isRepeating,
      };

  // ---------- One list per tab ----------

  /// Pending tasks due today or earlier (overdue ones stay visible).
  List<Task> get todayTasks =>
      _tasks
          .where((t) =>
      !t.isCompleted &&
          !t.dueDate.isAfter(_today) &&
          _matchesSearch(t) &&
          _matchesFilter(t))
          .toList();

  /// Pending tasks due after today.
  List<Task> get upcomingTasks =>
      _tasks
          .where((t) =>
      !t.isCompleted &&
          t.dueDate.isAfter(_today) &&
          _matchesSearch(t) &&
          _matchesFilter(t))
          .toList();

  /// Completed tasks, most recently completed first.
  List<Task> get completedTasks =>
      _tasks
          .where((t) => t.isCompleted && _matchesSearch(t))
          .toList()
        ..sort((a, b) =>
            (b.completedAt ?? b.createdAt)
                .compareTo(a.completedAt ?? a.createdAt));

  /// Every task marked as repeating, pending or completed.
  List<Task> get repeatedTasks =>
      _tasks.where((t) => t.isRepeating && _matchesSearch(t)).toList();

  // ---------- Data operations (unchanged from Phase 2) ----------

  Future<void> loadTasks() async {
    // Keep reminders in sync with the database after every load.
    try {
      await NotificationService.instance.rescheduleAll(_tasks);
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
    _isLoading = true;
    notifyListeners();
    _tasks = await _repo.getAllTasks();

    // Recurrence check on every load (app start, resume, any change).
    final changed = await _recurrence.processDueRules(_tasks);
    if (changed > 0) _tasks = await _repo.getAllTasks();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    await _repo.insertTask(task);
    // Phase 6: schedule the notification here.
    await loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await _repo.updateTask(task);
    // Phase 6: reschedule the notification here.
    await loadTasks();
  }

  Future<void> deleteTask(int id) async {
    await _repo.deleteTask(id);
    // Phase 6: cancel the notification here.
    await loadTasks();
  }

  Future<void> toggleComplete(Task task) async {
    await _repo.setCompleted(task.id!, !task.isCompleted);
    // Phase 6: cancel the notification when completed.
    await loadTasks();
  }
}