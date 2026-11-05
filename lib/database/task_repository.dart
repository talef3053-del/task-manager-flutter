import 'package:sqflite/sqflite.dart';

import '../models/recurrence_rule.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import 'database_helper.dart';

/// All SQL for tasks lives here. Screens and providers never write SQL.
class TaskRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Inserts a task, its subtasks and its recurrence rule in ONE transaction.
  /// If any step fails, nothing is saved. Returns the new task id.
  Future<int> insertTask(Task task) async {
    final db = await _db;
    return db.transaction((txn) async {
      final id = await txn.insert(
        DbConstants.tableTasks,
        task.toMap()
          ..remove('id'),
      );
      await _writeChildren(txn, id, task);
      return id;
    });
  }

  /// Writes the subtasks and the recurrence rule of a task.
  Future<void> _writeChildren(Transaction txn, int taskId, Task task) async {
    for (final s in task.subtasks) {
      await txn.insert(
        DbConstants.tableSubtasks,
        s.toMap()
          ..remove('id')
          ..['task_id'] = taskId,
      );
    }
    final r = task.recurrence;
    if (task.isRepeating && r != null) {
      await txn.insert(
        DbConstants.tableRecurrence,
        r.toMap()
          ..remove('id')
          ..['task_id'] = taskId,
      );
    }
  }

  /// Loads every task together with its subtasks and recurrence rule.
  /// Uses 3 queries in total (not one per task).
  Future<List<Task>> getAllTasks() async {
    final db = await _db;

    final taskRows = await db.query(
      DbConstants.tableTasks,
      orderBy: 'is_completed ASC, due_date ASC, due_time ASC',
    );

    final subRows = await db.query(
        DbConstants.tableSubtasks, orderBy: 'id ASC');
    final subsByTask = <int, List<Subtask>>{};
    for (final row in subRows) {
      final s = Subtask.fromMap(row);
      subsByTask.putIfAbsent(s.taskId, () => []).add(s);
    }

    final recRows = await db.query(DbConstants.tableRecurrence);
    final recByTask = <int, RecurrenceRule>{};
    for (final row in recRows) {
      final r = RecurrenceRule.fromMap(row);
      recByTask[r.taskId] = r;
    }

    return taskRows.map((row) {
      final id = row['id'] as int;
      return Task.fromMap(
        row,
        subtasks: subsByTask[id] ?? const [],
        recurrence: recByTask[id],
      );
    }).toList();
  }

  /// Updates the task and replaces its subtasks and recurrence rule.
  Future<void> updateTask(Task task) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        DbConstants.tableTasks,
        task.toMap()
          ..remove('id'),
        where: 'id = ?',
        whereArgs: [task.id],
      );
      await txn.delete(DbConstants.tableSubtasks,
          where: 'task_id = ?', whereArgs: [task.id]);
      await txn.delete(DbConstants.tableRecurrence,
          where: 'task_id = ?', whereArgs: [task.id]);
      await _writeChildren(txn, task.id!, task);
    });
  }

  /// Subtasks and the recurrence rule are removed automatically
  /// by ON DELETE CASCADE.
  Future<void> deleteTask(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tableTasks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks a task complete or pending. Only the two status columns change,
  /// so a repeating task keeps its recurrence configuration.
  Future<void> setCompleted(int id, bool completed) async {
    final db = await _db;
    await db.update(
      DbConstants.tableTasks,
      {
        'is_completed': completed ? 1 : 0,
        'completed_at': completed ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Starts a new occurrence of a repeating task: pending again, due today,
  /// subtasks unchecked, and last_generated_date stamped with today.
  /// The recurrence rule itself (type and weekdays) is never touched.
  Future<void> resetForNewOccurrence(int taskId, DateTime today) async {
    final db = await _db;
    final todayStr = AppDateUtils.formatDate(today);
    await db.transaction((txn) async {
      await txn.update(
        DbConstants.tableTasks,
        {'is_completed': 0, 'completed_at': null, 'due_date': todayStr},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.update(
        DbConstants.tableSubtasks,
        {'is_completed': 0},
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      await txn.update(
        DbConstants.tableRecurrence,
        {'last_generated_date': todayStr},
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
    });
  }
}