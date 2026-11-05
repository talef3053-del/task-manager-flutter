import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/constants.dart';

/// Opens the SQLite database, creates tables and handles upgrades.
/// Singleton: the whole app shares one connection.
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbFolder = await getDatabasesPath();
    final path = join(dbFolder, DbConstants.dbName);

    return openDatabase(
      path,
      version: DbConstants.dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// SQLite ignores foreign keys unless we switch them on for each connection.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Runs once, the first time the database file is created.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableTasks} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT NOT NULL,
        due_time TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        is_repeating INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableSubtasks} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES ${DbConstants.tableTasks}(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableRecurrence} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL UNIQUE,
        repeat_type TEXT NOT NULL,
        weekdays TEXT,
        last_generated_date TEXT,
        FOREIGN KEY (task_id) REFERENCES ${DbConstants.tableTasks}(id)
          ON DELETE CASCADE
      )
    ''');

    // Indexes make the Today / Completed / Repeated queries fast.
    await db.execute(
        'CREATE INDEX idx_tasks_due_date ON ${DbConstants
            .tableTasks}(due_date)');
    await db.execute(
        'CREATE INDEX idx_subtasks_task_id ON ${DbConstants
            .tableSubtasks}(task_id)');
  }

  /// Migration strategy: when the schema changes, raise
  /// DbConstants.dbVersion and add a block here. Existing user data is kept.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Example for a future version 2:
    // if (oldVersion < 2) {
    //   await db.execute(
    //       'ALTER TABLE ${DbConstants.tableTasks} ADD COLUMN priority INTEGER NOT NULL DEFAULT 0');
    // }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}