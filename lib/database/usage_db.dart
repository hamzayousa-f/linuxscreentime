import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class UsageDatabase {
  static final UsageDatabase instance = UsageDatabase._internal();
  static Database? _database;

  UsageDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('screen_time_usage.db');
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

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usage_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        app_name TEXT NOT NULL,
        minutes INTEGER NOT NULL
      )
    ''');
  }

  Future<void> insertUsage(
      DateTime dateTime, String appName, int minutes) async {
    final db = await database;
    await db.insert(
      'usage_table',
      {
        'timestamp': dateTime.toIso8601String(),
        'app_name': appName.toLowerCase().trim(),
        'minutes': minutes,
      },
    );
  }

  // Returns data with specific 'appName' and 'durationMinutes' aliases for the UI
  Future<List<Map<String, dynamic>>> getTodayUsage() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT app_name as appName, SUM(minutes) as durationMinutes 
      FROM usage_table 
      WHERE date(timestamp) = date('now', 'localtime')
      GROUP BY app_name
      ORDER BY durationMinutes DESC
    ''');

    return results.map((row) {
      return {
        'appName': row['appName'] ?? 'unknown application',
        'durationMinutes': row['durationMinutes'] ?? 0,
      };
    }).toList();
  }

  // Returns data with specific 'appName' and 'durationMinutes' aliases for the UI
  Future<List<Map<String, dynamic>>> getWeeklyUsage() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT app_name as appName, SUM(minutes) as durationMinutes 
      FROM usage_table 
      WHERE date(timestamp) >= date('now', '-6 days', 'localtime')
      GROUP BY app_name
      ORDER BY durationMinutes DESC
    ''');

    return results.map((row) {
      return {
        'appName': row['appName'] ?? 'unknown application',
        'durationMinutes': row['durationMinutes'] ?? 0,
      };
    }).toList();
  }

  // Alias linking method for weekly view screen template
  Future<List<Map<String, dynamic>>> getLast7DaysUsage() async {
    return await getWeeklyUsage();
  }

  // Returns data with specific 'appName' and 'durationMinutes' aliases for the UI
  Future<List<Map<String, dynamic>>> getUsageByDate(DateTime date) async {
    final db = await database;
    final String targetDateString =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT app_name as appName, SUM(minutes) as durationMinutes 
      FROM usage_table 
      WHERE date(timestamp) = ?
      GROUP BY app_name
      ORDER BY durationMinutes DESC
    ''', [targetDateString]);

    return results.map((row) {
      return {
        'appName': row['appName'] ?? 'unknown application',
        'durationMinutes': row['durationMinutes'] ?? 0,
      };
    }).toList();
  }

  // Bulletproof fallback calculation check for dashboard indicators
  Future<int> getTotalMinutesToday() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(minutes) as total 
      FROM usage_table 
      WHERE date(timestamp) = date('now', 'localtime')
    ''');

    if (result.isNotEmpty && result.first['total'] != null) {
      return int.tryParse(result.first['total'].toString()) ?? 0;
    }
    return 0;
  }
}
