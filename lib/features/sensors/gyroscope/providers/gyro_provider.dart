import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/models/session.dart';
import '../../../../core/services/data_repository.dart';
import '../../gps_traces/providers/gps_provider.dart';

/// State for gyroscope feature.
class GyroState {
  final bool isRecording;
  final List<GyroReading> recentReadings;
  final List<Session> sessions;
  final int readingCount;

  const GyroState({
    this.isRecording = false,
    this.recentReadings = const [],
    this.sessions = const [],
    this.readingCount = 0,
  });

  GyroState copyWith({
    bool? isRecording,
    List<GyroReading>? recentReadings,
    List<Session>? sessions,
    int? readingCount,
  }) =>
      GyroState(
        isRecording: isRecording ?? this.isRecording,
        recentReadings: recentReadings ?? this.recentReadings,
        sessions: sessions ?? this.sessions,
        readingCount: readingCount ?? this.readingCount,
      );
}

class GyroReading {
  final double x, y, z;
  final DateTime timestamp;

  GyroReading({required this.x, required this.y, required this.z, required this.timestamp});
}

class GyroNotifier extends StateNotifier<GyroState> {
  final DataRepository _repo;
  StreamSubscription? _gyroSub;
  Timer? _flushTimer;
  final List<Map<String, dynamic>> _buffer = [];
  int _count = 0;
  String? _sessionId;
  static const _maxRecent = 200;

  GyroNotifier(this._repo) : super(const GyroState()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _repo.getSessions('gyroscope');
    state = state.copyWith(sessions: sessions);
  }

  void startRecording({int sampleRateHz = 20}) {
    final sessionId = const Uuid().v4();
    _sessionId = sessionId;
    _count = 0;

    _repo.insertSession(Session(
      id: sessionId,
      sensorType: 'gyroscope',
      startTime: DateTime.now(),
    ));

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: Duration(microseconds: (1000000 / sampleRateHz).round()),
    ).listen((event) {
      final reading = GyroReading(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );

      _buffer.add({
        'session_id': sessionId,
        'x': event.x,
        'y': event.y,
        'z': event.z,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _count++;

      final recent = [...state.recentReadings, reading];
      if (recent.length > _maxRecent) recent.removeRange(0, recent.length - _maxRecent);
      state = state.copyWith(recentReadings: recent, readingCount: _count);
    });

    _flushTimer = Timer.periodic(const Duration(seconds: 3), (_) => _flushBuffer());
    state = state.copyWith(isRecording: true, recentReadings: [], readingCount: 0);
  }

  Future<void> stopRecording() async {
    _gyroSub?.cancel();
    _gyroSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flushBuffer();
    if (_sessionId != null) await _repo.endSession(_sessionId!, _count);
    state = state.copyWith(isRecording: false);
    await _loadSessions();
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final db = await DbHelper.database;
    final batch = db.batch();
    for (final m in _buffer) {
      batch.insert('gyro_records', m);
    }
    _buffer.clear();
    await batch.commit(noResult: true);
  }

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId, 'gyro_records');
    await _loadSessions();
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}

final gyroProvider = StateNotifierProvider<GyroNotifier, GyroState>((ref) {
  return GyroNotifier(ref.watch(dataRepositoryProvider));
});
