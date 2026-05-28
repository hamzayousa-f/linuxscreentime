import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class UsageDatabase {
  static final UsageDatabase instance = UsageDatabase._init();
  static Database? _database;

  UsageDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('screen_time.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await databaseFactoryFfi.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
      ),
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appName TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        UNIQUE(appName, date)
      )
    ''');
  }

  // Insert or Update usage minutes (Upsert)
  Future<void> insertUsage(DateTime date, String appName, int minutes) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().split('T')[0]; // Format: YYYY-MM-DD

    await db.execute('''
      INSERT INTO usage (appName, durationMinutes, date)
      VALUES (?, ?, ?)
      ON CONFLICT(appName, date) DO UPDATE SET
      durationMinutes = durationMinutes + excluded.durationMinutes
    ''', [appName, minutes, dateString]);
  }

  // Fetch usage data for today
  Future<List<Map<String, dynamic>>> getUsageByDate(DateTime date) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().split('T')[0];

    return await db.query(
      'usage',
      where: 'date = ?',
      whereArgs: [dateString],
      orderBy: 'durationMinutes DESC',
    );
  }

  // Fetch usage data for the last 7 days
  Future<List<Map<String, dynamic>>> getLast7DaysUsage() async {
    final db = await instance.database;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final startDateString = sevenDaysAgo.toIso8601String().split('T')[0];

    return await db.query(
      'usage',
      where: 'date >= ?',
      whereArgs: [startDateString],
      orderBy: 'date DESC, durationMinutes DESC',
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}