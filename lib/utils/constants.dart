/// Central place for database names so we never mistype a string.
class DbConstants {
  static const String dbName = 'task_manager.db';
  static const int dbVersion = 1;

  // Tables
  static const String tableTasks = 'tasks';
  static const String tableSubtasks = 'subtasks';
  static const String tableRecurrence = 'recurrence_rules';
}