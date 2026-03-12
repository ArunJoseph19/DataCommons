import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;
import 'package:uuid/uuid.dart';
import '../../../../core/models/gps_point.dart';
import '../../../../core/models/session.dart';
import '../../../../core/services/data_repository.dart';
import '../../../../core/services/location_service.dart';

/// State for the GPS tracking feature.
class GpsState {
  final bool isRecording;
  final String? currentSessionId;
  final List<GpsPoint> currentPoints;
  final List<Session> sessions;
  final int pointCount;

  const GpsState({
    this.isRecording = false,
    this.currentSessionId,
    this.currentPoints = const [],
    this.sessions = const [],
    this.pointCount = 0,
  });

  GpsState copyWith({
    bool? isRecording,
    String? currentSessionId,
    List<GpsPoint>? currentPoints,
    List<Session>? sessions,
    int? pointCount,
  }) =>
      GpsState(
        isRecording: isRecording ?? this.isRecording,
        currentSessionId: currentSessionId ?? this.currentSessionId,
        currentPoints: currentPoints ?? this.currentPoints,
        sessions: sessions ?? this.sessions,
        pointCount: pointCount ?? this.pointCount,
      );
}

/// Provider for GPS tracking.
class GpsNotifier extends StateNotifier<GpsState> {
  final DataRepository _repo;
  final LocationService _locationService;
  StreamSubscription? _locationSub;
  final List<GpsPoint> _buffer = [];
  Timer? _flushTimer;

  GpsNotifier(this._repo, this._locationService) : super(const GpsState()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _repo.getSessions('gps');
    state = state.copyWith(sessions: sessions);
  }

  /// Start recording a GPS trace.
  Future<void> startRecording() async {
    final sessionId = const Uuid().v4();

    await _repo.insertSession(Session(
      id: sessionId,
      sensorType: 'gps',
      startTime: DateTime.now(),
    ));

    _locationService.startTracking(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _locationSub = _locationService.positionStream.listen((position) {
      final point = GpsPoint(
        sessionId: sessionId,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );

      _buffer.add(point);
      state = state.copyWith(
        currentPoints: [...state.currentPoints, point],
        pointCount: state.pointCount + 1,
      );
    });

    // Flush buffer to DB every 5 seconds
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => _flushBuffer());

    state = state.copyWith(
      isRecording: true,
      currentSessionId: sessionId,
      currentPoints: [],
      pointCount: 0,
    );
  }

  /// Stop recording.
  Future<void> stopRecording() async {
    _locationSub?.cancel();
    _locationSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _locationService.stopTracking();

    await _flushBuffer();

    if (state.currentSessionId != null) {
      await _repo.endSession(state.currentSessionId!, state.pointCount);
    }

    state = state.copyWith(
      isRecording: false,
    );

    await _loadSessions();
  }

  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final points = List<GpsPoint>.from(_buffer);
    _buffer.clear();
    await _repo.insertGpsPointsBatch(points);
  }

  /// Load points for a specific session.
  Future<List<GpsPoint>> getSessionPoints(String sessionId) async {
    return _repo.getGpsPoints(sessionId);
  }

  /// Delete a session and its points.
  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId, 'gps_points');
    await _loadSessions();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}

/// Riverpod providers
final dataRepositoryProvider = Provider<DataRepository>((ref) {
  return DataRepository();
});

final gpsProvider = StateNotifierProvider<GpsNotifier, GpsState>((ref) {
  return GpsNotifier(
    ref.watch(dataRepositoryProvider),
    ref.watch(locationServiceProvider),
  );
});
