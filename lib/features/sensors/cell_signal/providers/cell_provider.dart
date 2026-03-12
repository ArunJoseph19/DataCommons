import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/models/session.dart';
import '../../../../core/services/data_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../gps_traces/providers/gps_provider.dart';

/// Cell signal reading.
class CellReading {
  final int? signalStrength;
  final String? networkType;
  final String? carrier;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  CellReading({
    this.signalStrength,
    this.networkType,
    this.carrier,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

class CellState {
  final bool isRecording;
  final CellReading? latestReading;
  final List<Session> sessions;
  final int readingCount;

  const CellState({this.isRecording = false, this.latestReading, this.sessions = const [], this.readingCount = 0});

  CellState copyWith({bool? isRecording, CellReading? latestReading, List<Session>? sessions, int? readingCount}) =>
      CellState(
        isRecording: isRecording ?? this.isRecording,
        latestReading: latestReading ?? this.latestReading,
        sessions: sessions ?? this.sessions,
        readingCount: readingCount ?? this.readingCount,
      );
}

class CellNotifier extends StateNotifier<CellState> {
  final DataRepository _repo;
  final LocationService _locationService;
  Timer? _pollTimer;
  final List<Map<String, dynamic>> _buffer = [];
  int _count = 0;
  String? _sessionId;

  CellNotifier(this._repo, this._locationService) : super(const CellState()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _repo.getSessions('cell_signal');
    state = state.copyWith(sessions: sessions);
  }

  /// Start recording. Requires Android platform channel for actual signal data.
  void startRecording() {
    final sessionId = const Uuid().v4();
    _sessionId = sessionId;
    _count = 0;

    _repo.insertSession(Session(
      id: sessionId,
      sensorType: 'cell_signal',
      startTime: DateTime.now(),
    ));

    // Poll every 10 seconds — actual signal reading needs platform channel
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      final reading = CellReading(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      _buffer.add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _count++;

      state = state.copyWith(latestReading: reading, readingCount: _count);
      if (_buffer.length >= 6) await _flushBuffer();
    });

    state = state.copyWith(isRecording: true, readingCount: 0);
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
    for (final m in _buffer) batch.insert('cell_signal_records', m);
    _buffer.clear();
    await batch.commit(noResult: true);
  }

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId, 'cell_signal_records');
    await _loadSessions();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final cellProvider = StateNotifierProvider<CellNotifier, CellState>((ref) {
  return CellNotifier(ref.watch(dataRepositoryProvider), ref.watch(locationServiceProvider));
});
