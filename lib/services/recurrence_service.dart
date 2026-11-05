import '../database/task_repository.dart';
import '../models/task.dart';
import '../utils/date_utils.dart';

/// Decides which repeating tasks need a fresh occurrence today.
class RecurrenceService {
  RecurrenceService(this._repo);

  final TaskRepository _repo;

  /// Returns how many tasks were reset.
  Future<int> processDueRules(List<Task> tasks) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = AppDateUtils.formatDate(today);
    var resetCount = 0;

    for (final task in tasks) {
      final rule = task.recurrence;
      if (!task.isRepeating || rule == null) continue;

      // 1. Does the rule apply today (daily, or today's weekday selected)?
      if (!rule.appliesOn(today)) continue;
      // 2. Duplicate guard: already generated today.
      if (rule.lastGeneratedDate == todayStr) continue;
      // 3. The task's start date has not arrived yet.
      if (task.dueDate.isAfter(today)) continue;

      await _repo.resetForNewOccurrence(task.id!, today);
      // Phase 6: reschedule this task's notification here.
      resetCount++;
    }
    return resetCount;
  }
}