import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/models/accel_record.dart';
import '../../../../core/models/session.dart';
import '../../../../core/services/data_repository.dart';
import '../../gps_traces/providers/gps_provider.dart';

/// State for the accelerometer feature.
class AccelState {
  final bool isRecording;
  final String? currentSessionId;
  final List<AccelRecord> recentPoints; // last ~200 for live chart
  final List<Session> sessions;
  final int sampleRate; // Hz

  const AccelState({
    this.isRecording = false,
    this.currentSessionId,
    this.recentPoints = const [],
    this.sessions = const [],
    this.sampleRate = 20,
  });

  AccelState copyWith({
    bool? isRecording,
    String? currentSessionId,
    List<AccelRecord>? recentPoints,
    List<Session>? sessions,
    int? sampleRate,
  }) =>
      AccelState(
        isRecording: isRecording ?? this.isRecording,
        currentSessionId: currentSessionId ?? this.currentSessionId,
        recentPoints: recentPoints ?? this.recentPoints,
        sessions: sessions ?? this.sessions,
        sampleRate: sampleRate ?? this.sampleRate,
      );
}

class AccelNotifier extends StateNotifier<AccelState> {
  final DataRepository _repo;
  StreamSubscription? _accelSub;
  final List<AccelRecord> _buffer = [];
  Timer? _flushTimer;
  int _count = 0;
  static const _maxRecentPoints = 200;

  AccelNotifier(this._repo) : super(const AccelState()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _repo.getSessions('accelerometer');
    state = state.copyWith(sessions: sessions);
  }

  void startRecording() {
    final sessionId = const Uuid().v4();
    _count = 0;

    _repo.insertSession(Session(
      id: sessionId,
      sensorType: 'accelerometer',
      startTime: DateTime.now(),
    ));

    // Use userAccelerometerEvents for linear acceleration (gravity subtracted)
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: Duration(
        microseconds: (1000000 / state.sampleRate).round(),
      ),
    ).listen((event) {
      final record = AccelRecord(
        sessionId: sessionId,
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: DateTime.now(),
      );

      _buffer.add(record);
      _count++;

      // Keep recent points for live chart
      final recent = [...state.recentPoints, record];
      if (recent.length > _maxRecentPoints) {
        recent.removeRange(0, recent.length - _maxRecentPoints);
      }
      state = state.copyWith(recentPoints: recent);
    });

    _flushTimer = Timer.periodic(const Duration(seconds: 3), (_) => _flushBuffer());

    state = state.copyWith(
      isRecording: true,
      currentSessionId: sessionId,
      recentPoints: [],
    );
  }

  Future<void> stopRecording() async {
    _accelSub?.cancel();
    _accelSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    await _flushBuffer();

    if (state.currentSessionId != null) {
      await _repo.endSession(state.currentSessionId!, _count);
    }

    state = state.copyWith(isRecording: false);
    await _loadSessions();
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final records = List<AccelRecord>.from(_buffer);
    _buffer.clear();
    await _repo.insertAccelBatch(records);
  }

  void setSampleRate(int hz) {
    state = state.copyWith(sampleRate: hz);
  }

  Future<List<AccelRecord>> getSessionRecords(String sessionId) async {
    return _repo.getAccelRecords(sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId, 'accel_records');
    await _loadSessions();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}

final accelProvider = StateNotifierProvider<AccelNotifier, AccelState>((ref) {
  return AccelNotifier(ref.watch(dataRepositoryProvider));
});
