import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class SyncDatabase {
  static final SyncDatabase instance = SyncDatabase._init();
  static Database? _database;

  // ValueNotifier to notify UI about the count of failed sync logs
  static final ValueNotifier<int> failedLogsCount = ValueNotifier<int>(0);

  SyncDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sync_queue.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
CREATE TABLE sync_requests (
  id $idType,
  image_filename $textType,
  payload $textTypeNullable,
  created_at $textType
)
''');

    await db.execute('''
CREATE TABLE failed_sync_logs (
  id $idType,
  employee_id INTEGER,
  employee_name $textTypeNullable,
  error_message $textType,
  timestamp $textType
)
''');
  }

  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS failed_sync_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER,
  employee_name TEXT,
  error_message TEXT NOT NULL,
  timestamp TEXT NOT NULL
)
''');
    }
  }

  // === Failed Sync Logs Helper Methods ===

  Future<int> insertFailedLog(int? employeeId, String? employeeName, String errorMessage) async {
    final db = await instance.database;
    final data = {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'error_message': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final id = await db.insert('failed_sync_logs', data);
    await updateFailedLogsCount();
    return id;
  }

  Future<List<Map<String, dynamic>>> getFailedLogs() async {
    final db = await instance.database;
    return await db.query('failed_sync_logs', orderBy: 'id DESC');
  }

  Future<int> deleteFailedLog(int id) async {
    final db = await instance.database;
    final count = await db.delete(
      'failed_sync_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
    await updateFailedLogsCount();
    return count;
  }

  Future<int> clearAllFailedLogs() async {
    final db = await instance.database;
    final count = await db.delete('failed_sync_logs');
    await updateFailedLogsCount();
    return count;
  }

  Future<int> deleteOldFailedLogs(int days) async {
    final db = await instance.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final count = await db.delete(
      'failed_sync_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate],
    );
    await updateFailedLogsCount();
    return count;
  }

  Future<void> updateFailedLogsCount() async {
    try {
      final db = await instance.database;
      final countResult = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM failed_sync_logs'),
      );
      failedLogsCount.value = countResult ?? 0;
    } catch (e) {
      // If table doesn't exist yet
      failedLogsCount.value = 0;
    }
  }

  // === Sync Requests Helper Methods ===

  Future<int> insertRequest(String imageFilename, {String? payload}) async {
    final db = await instance.database;
    final data = {
      'image_filename': imageFilename,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    };
    return await db.insert('sync_requests', data);
  }

  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final db = await instance.database;
    return await db.query('sync_requests', orderBy: 'id ASC');
  }

  Future<int> deleteRequest(int id) async {
    final db = await instance.database;
    return await db.delete(
      'sync_requests',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
