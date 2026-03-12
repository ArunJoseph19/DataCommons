import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/db_helper.dart';
import '../../../../core/models/session.dart';
import '../../../../core/services/data_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../gps_traces/providers/gps_provider.dart';

/// Ambient light reading.
class LightReading {
  final double lux;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LightReading({required this.lux, required this.latitude, required this.longitude, required this.timestamp});
}

class LightState {
  final bool isRecording;
  final double? currentLux;
  final List<LightReading> recentReadings;
  final List<Session> sessions;
  final int readingCount;

  const LightState({this.isRecording = false, this.currentLux, this.recentReadings = const [], this.sessions = const [], this.readingCount = 0});

  LightState copyWith({bool? isRecording, double? currentLux, List<LightReading>? recentReadings, List<Session>? sessions, int? readingCount}) =>
      LightState(
        isRecording: isRecording ?? this.isRecording,
        currentLux: currentLux ?? this.currentLux,
        recentReadings: recentReadings ?? this.recentReadings,
        sessions: sessions ?? this.sessions,
        readingCount: readingCount ?? this.readingCount,
      );
}

class LightNotifier extends StateNotifier<LightState> {
  final DataRepository _repo;
  final LocationService _locationService;
  Timer? _pollTimer;
  final List<Map<String, dynamic>> _buffer = [];
  int _count = 0;
  String? _sessionId;
  static const _maxRecent = 100;

  LightNotifier(this._repo, this._locationService) : super(const LightState()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _repo.getSessions('ambient_light');
    state = state.copyWith(sessions: sessions);
  }

  /// Start recording. Uses platform channel for light sensor on Android.
  /// For now, we use a simulated fallback since the sensors_plus package
  /// does not expose the ambient light sensor directly.
  void startRecording() {
    final sessionId = const Uuid().v4();
    _sessionId = sessionId;
    _count = 0;

    _repo.insertSession(Session(
      id: sessionId,
      sensorType: 'ambient_light',
      startTime: DateTime.now(),
    ));

    // Poll every 5 seconds — actual sensor integration pending platform channel
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      // Placeholder: in production, read from TYPE_LIGHT Android sensor
      // For now, store location with lux=0 as placeholder
      _buffer.add({
        'lux': 0.0,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _count++;

      final reading = LightReading(
        lux: 0.0,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );
      final recent = [...state.recentReadings, reading];
      if (recent.length > _maxRecent) recent.removeRange(0, recent.length - _maxRecent);
      state = state.copyWith(currentLux: 0.0, recentReadings: recent, readingCount: _count);

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
    for (final m in _buffer) batch.insert('light_records', m);
    _buffer.clear();
    await batch.commit(noResult: true);
  }

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId, 'light_records');
    await _loadSessions();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final lightProvider = StateNotifierProvider<LightNotifier, LightState>((ref) {
  return LightNotifier(ref.watch(dataRepositoryProvider), ref.watch(locationServiceProvider));
});
