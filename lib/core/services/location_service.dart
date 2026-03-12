import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Provides location access: current position and continuous stream.
class LocationService {
  StreamSubscription<Position>? _subscription;
  final _controller = StreamController<Position>.broadcast();

  /// Stream of position updates.
  Stream<Position> get positionStream => _controller.stream;

  /// Get current position (one-shot).
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Start continuous location updates.
  void startTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
    int intervalMs = 1000,
  }) {
    _subscription?.cancel();

    _subscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: Duration(milliseconds: intervalMs),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'DataCommons',
          notificationText: 'Recording location data',
          enableWakeLock: true,
        ),
      ),
    ).listen(
      (position) {
        // Filter out inaccurate readings (> 20m)
        if (position.accuracy <= 20) {
          _controller.add(position);
        }
      },
      onError: (error) {
        _controller.addError(error);
      },
    );
  }

  /// Stop location updates.
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Dispose resources.
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// Riverpod provider for the location service.
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});
