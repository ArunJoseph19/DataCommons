import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/models/session.dart';
import '../../../../core/services/data_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../gps_traces/providers/gps_provider.dart';

/// A barometer reading with pressure and location.
class BaroReading {
  final double pressure;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  BaroReading({
    required this.pressure,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'pressure': pressure,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// State for the barometer feature.
class BaroState {
  final bool isRecording;
  final double? currentPressure;
  final List<BaroReading> recentReadings;
  final List<Session> sessions;
  final int readingCount;

  const BaroState({
    this.isRecording = false,
    this.currentPressure,
    this.recentReadings = const [],
    this.sessions = const [],
    this.readingCount = 0,
  });

  BaroState copyWith({
    bool? isRecording,
    double? currentPressure,
    List<BaroReading>? recentReadings,
    List<Session>? sessions,
    int? readingCount,
  }) =>
      BaroState(
        isRecording: isRecording ?? this.isRecording,
        currentPressure: currentPressure ?? this.currentPressure,
        recentReadings: recentReadings ?? this.recentReadings,
        sessions: sessions ?? this.sessions,
        readingCount: readingCount ?? this.readingCount,
      );
}

class BaroNotifier extends StateNotifier<BaroState> {
  final DataRepository _repo;
  final LocationService _locationService;
  StreamSubscription? _baroSub;
  Timer? _flushTimer;
  final List<Map<String, dynamic>> _buffer = [];
  int _count = 0;
  String? _currentSessionId;
  static const _maxRecent = 100;

  BaroNotifier(this._repo, this._locationService) : super(const BaroState()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _repo.getSessions('barometer');
    state = state.copyWith(sessions: sessions);
  }

  void startRecording() {
    final sessionId = const Uuid().v4();
    _currentSessionId = sessionId;
    _count = 0;

    _repo.insertSession(Session(
      id: sessionId,
      sensorType: 'barometer',
      startTime: DateTime.now(),
    ));

    _baroSub = barometerEventStream(
      samplingPeriod: const Duration(seconds: 2),
    ).listen((event) async {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      final reading = BaroReading(
        pressure: event.pressure,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      _buffer.add(reading.toMap());
      _count++;

      final recent = [...state.recentReadings, reading];
      if (recent.length > _maxRecent) {
        recent.removeRange(0, recent.length - _maxRecent);
      }

      state = state.copyWith(
        currentPressure: event.pressure,
        recentReadings: recent,
        readingCount: _count,
      );
    });

    _flushTimer = Timer.periodic(const Duration(seconds: 10), (_) => _flushBuffer());

    state = state.copyWith(
      isRecording: true,
      recentReadings: [],
      readingCount: 0,
    );
  }

  Future<void> stopRecording() async {
    _baroSub?.cancel();
    _baroSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    await _flushBuffer();

    if (_currentSessionId != null) {
      await _repo.endSession(_currentSessionId!, _count);
    }

    state = state.copyWith(isRecording: false);
    await _loadSessions();
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final db = await DbHelper.database;
    final batch = db.batch();
    for (final m in _buffer) {
      batch.insert('baro_records', m);
    }
    _buffer.clear();
    await batch.commit(noResult: true);
  }

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId, 'baro_records');
    await _loadSessions();
  }

  @override
  void dispose() {
    _baroSub?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}

final baroProvider = StateNotifierProvider<BaroNotifier, BaroState>((ref) {
  return BaroNotifier(
    ref.watch(dataRepositoryProvider),
    ref.watch(locationServiceProvider),
  );
});
