import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/models/session.dart';
import '../../../../core/services/data_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../gps_traces/providers/gps_provider.dart';

/// Altitude reading from GPS + optional barometric altitude.
class AltReading {
  final double gpsAltitude;
  final double? baroAltitude;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  AltReading({
    required this.gpsAltitude,
    this.baroAltitude,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

class AltState {
  final bool isRecording;
  final double? currentAltitude;
  final List<AltReading> recentReadings;
  final List<Session> sessions;
  final int readingCount;

  const AltState({
    this.isRecording = false,
    this.currentAltitude,
    this.recentReadings = const [],
    this.sessions = const [],
    this.readingCount = 0,
  });

  AltState copyWith({
    bool? isRecording,
    double? currentAltitude,
    List<AltReading>? recentReadings,
    List<Session>? sessions,
    int? readingCount,
  }) =>
      AltState(
        isRecording: isRecording ?? this.isRecording,
        currentAltitude: currentAltitude ?? this.currentAltitude,
        recentReadings: recentReadings ?? this.recentReadings,
        sessions: sessions ?? this.sessions,
        readingCount: readingCount ?? this.readingCount,
      );
}

class AltNotifier extends StateNotifier<AltState> {
  final DataRepository _repo;
  final LocationService _locationService;
  Timer? _pollTimer;
  final List<Map<String, dynamic>> _buffer = [];
  int _count = 0;
  String? _sessionId;
  static const _maxRecent = 100;

  AltNotifier(this._repo, this._locationService) : super(const AltState()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _repo.getSessions('altitude');
    state = state.copyWith(sessions: sessions);
  }

  void startRecording() {
    final sessionId = const Uuid().v4();
    _sessionId = sessionId;
    _count = 0;

    _repo.insertSession(Session(
      id: sessionId,
      sensorType: 'altitude',
      startTime: DateTime.now(),
    ));

    // Poll GPS altitude every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      final reading = AltReading(
        gpsAltitude: position.altitude,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      _buffer.add({
        'session_id': sessionId,
        'gps_altitude': position.altitude,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _count++;

      final recent = [...state.recentReadings, reading];
      if (recent.length > _maxRecent) recent.removeRange(0, recent.length - _maxRecent);
      state = state.copyWith(
        currentAltitude: position.altitude,
        recentReadings: recent,
        readingCount: _count,
      );

      // Flush every 10 readings
      if (_buffer.length >= 10) await _flushBuffer();
    });

    state = state.copyWith(isRecording: true, recentReadings: [], readingCount: 0);
  }

  Future<void> stopRecording() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _flushBuffer();
    if (_sessionId != null) await _repo.endSession(_sessionId!, _count);
    state = state.copyWith(isRecording: false);
    await _loadSessions();
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final db = await DbHelper.database;
    final batch = db.batch();
    for (final m in _buffer) batch.insert('altitude_records', m);
    _buffer.clear();
    await batch.commit(noResult: true);
  }

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId, 'altitude_records');
    await _loadSessions();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final altProvider = StateNotifierProvider<AltNotifier, AltState>((ref) {
  return AltNotifier(ref.watch(dataRepositoryProvider), ref.watch(locationServiceProvider));
});
