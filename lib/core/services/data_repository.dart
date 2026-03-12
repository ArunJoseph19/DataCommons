import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/gps_point.dart';
import '../models/accel_record.dart';
import '../models/step_record.dart';
import '../models/camera_record.dart';
import '../models/session.dart';

/// Local data repository — reads/writes to sqflite.
///
/// All sensor data access goes through this class.
/// When Firebase sync is added, a FirebaseRepository with the same
/// interface can be swapped in via Riverpod overrides.
class DataRepository {
  // ─── Sessions ───

  Future<void> insertSession(Session session) async {
    final db = await DbHelper.database;
    await db.insert('sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> endSession(String sessionId, int recordCount) async {
    final db = await DbHelper.database;
    await db.update(
      'sessions',
      {
        'end_time': DateTime.now().toIso8601String(),
        'record_count': recordCount,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<Session>> getSessions(String sensorType) async {
    final db = await DbHelper.database;
    final maps = await db.query(
      'sessions',
      where: 'sensor_type = ?',
      whereArgs: [sensorType],
      orderBy: 'start_time DESC',
    );
    return maps.map((m) => Session.fromMap(m)).toList();
  }

  Future<int> getTotalRecordCount() async {
    final db = await DbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(record_count), 0) as total FROM sessions',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  // ─── GPS Points ───

  Future<void> insertGpsPoint(GpsPoint point) async {
    final db = await DbHelper.database;
    await db.insert('gps_points', point.toMap());
  }

  Future<void> insertGpsPointsBatch(List<GpsPoint> points) async {
    final db = await DbHelper.database;
    final batch = db.batch();
    for (final p in points) {
      batch.insert('gps_points', p.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<GpsPoint>> getGpsPoints(String sessionId) async {
    final db = await DbHelper.database;
    final maps = await db.query(
      'gps_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => GpsPoint.fromMap(m)).toList();
  }

  Future<List<GpsPoint>> getAllGpsPoints({int? limit}) async {
    final db = await DbHelper.database;
    final maps = await db.query(
      'gps_points',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => GpsPoint.fromMap(m)).toList();
  }

  Future<int> getGpsPointCount(String sessionId) async {
    final db = await DbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM gps_points WHERE session_id = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ─── Accelerometer Records ───

  Future<void> insertAccelRecord(AccelRecord record) async {
    final db = await DbHelper.database;
    await db.insert('accel_records', record.toMap());
  }

  Future<void> insertAccelBatch(List<AccelRecord> records) async {
    final db = await DbHelper.database;
    final batch = db.batch();
    for (final r in records) {
      batch.insert('accel_records', r.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<AccelRecord>> getAccelRecords(String sessionId) async {
    final db = await DbHelper.database;
    final maps = await db.query(
      'accel_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => AccelRecord.fromMap(m)).toList();
  }

  // ─── Step Records ───

  Future<void> insertStepRecord(StepRecord record) async {
    final db = await DbHelper.database;
    await db.insert('step_records', record.toMap());
  }

  Future<List<StepRecord>> getStepRecordsByDate(String date) async {
    final db = await DbHelper.database;
    final maps = await db.query(
      'step_records',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return maps.map((m) => StepRecord.fromMap(m)).toList();
  }

  Future<List<StepRecord>> getStepRecordsRange(
      String startDate, String endDate) async {
    final db = await DbHelper.database;
    // Get the latest record per day within the range
    final maps = await db.rawQuery('''
      SELECT * FROM step_records
      WHERE date >= ? AND date <= ?
      GROUP BY date
      HAVING timestamp = MAX(timestamp)
      ORDER BY date ASC
    ''', [startDate, endDate]);
    return maps.map((m) => StepRecord.fromMap(m)).toList();
  }

  // ─── Camera Records ───

  Future<void> insertCameraRecord(CameraRecord record) async {
    final db = await DbHelper.database;
    await db.insert('camera_records', record.toMap());
  }

  Future<List<CameraRecord>> getAllCameraRecords() async {
    final db = await DbHelper.database;
    final maps = await db.query(
      'camera_records',
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => CameraRecord.fromMap(m)).toList();
  }

  Future<List<CameraRecord>> getCameraRecordsByCategory(
      String category) async {
    final db = await DbHelper.database;
    final maps = await db.query(
      'camera_records',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => CameraRecord.fromMap(m)).toList();
  }

  // ─── Generic helpers ───

  Future<int> getTableCount(String table) async {
    final db = await DbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteSession(String sessionId, String table) async {
    final db = await DbHelper.database;
    await db.delete(table, where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }
}
