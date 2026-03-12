import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sensors/gps_traces/providers/gps_provider.dart';
import '../../features/sensors/step_counter/providers/step_provider.dart';
import '../../features/sensors/accelerometer/providers/accel_provider.dart';
import '../../features/sensors/barometer/providers/baro_provider.dart';
import '../../features/sensors/gyroscope/providers/gyro_provider.dart';
import '../../features/sensors/altitude/providers/alt_provider.dart';
import '../../features/sensors/cell_signal/providers/cell_provider.dart';
import '../../features/sensors/ambient_light/providers/light_provider.dart';
import '../services/permission_service.dart';

/// Orchestrates starting/stopping sensors from the dashboard toggles.
/// Handles permissions and routes to the correct provider.
class SensorOrchestrator {
  /// Start a sensor by ID. Returns true if started successfully.
  static Future<bool> startSensor(
    String sensorId,
    WidgetRef ref,
    BuildContext context,
  ) async {
    switch (sensorId) {
      case 'gps':
        final granted = await PermissionService.requestLocation(context);
        if (!granted) return false;
        await ref.read(gpsProvider.notifier).startRecording();
        return true;

      case 'steps':
        final granted =
            await PermissionService.requestActivityRecognition(context);
        if (!granted) return false;
        ref.read(stepProvider.notifier).startTracking();
        return true;

      case 'accelerometer':
        ref.read(accelProvider.notifier).startRecording();
        return true;

      case 'barometer':
        final granted = await PermissionService.requestLocation(context);
        if (!granted) return false;
        ref.read(baroProvider.notifier).startRecording();
        return true;

      case 'gyroscope':
        ref.read(gyroProvider.notifier).startRecording();
        return true;

      case 'altitude':
        final granted = await PermissionService.requestLocation(context);
        if (!granted) return false;
        ref.read(altProvider.notifier).startRecording();
        return true;

      case 'cell_signal':
        final granted = await PermissionService.requestLocation(context);
        if (!granted) return false;
        ref.read(cellProvider.notifier).startRecording();
        return true;

      case 'ambient_light':
        final granted = await PermissionService.requestLocation(context);
        if (!granted) return false;
        ref.read(lightProvider.notifier).startRecording();
        return true;

      case 'camera':
      case 'od':
        // Camera and OD are manual — not toggle-based
        return false;

      default:
        return false;
    }
  }

  /// Stop a sensor by ID.
  static Future<void> stopSensor(String sensorId, WidgetRef ref) async {
    switch (sensorId) {
      case 'gps':
        await ref.read(gpsProvider.notifier).stopRecording();
      case 'steps':
        ref.read(stepProvider.notifier).stopTracking();
      case 'accelerometer':
        await ref.read(accelProvider.notifier).stopRecording();
      case 'barometer':
        await ref.read(baroProvider.notifier).stopRecording();
      case 'gyroscope':
        await ref.read(gyroProvider.notifier).stopRecording();
      case 'altitude':
        await ref.read(altProvider.notifier).stopRecording();
      case 'cell_signal':
        await ref.read(cellProvider.notifier).stopRecording();
      case 'ambient_light':
        await ref.read(lightProvider.notifier).stopRecording();
    }
  }

  /// Check if a sensor is currently recording (from its provider state).
  static bool isSensorRecording(String sensorId, WidgetRef ref) {
    switch (sensorId) {
      case 'gps':
        return ref.read(gpsProvider).isRecording;
      case 'steps':
        return ref.read(stepProvider).isTracking;
      case 'accelerometer':
        return ref.read(accelProvider).isRecording;
      case 'barometer':
        return ref.read(baroProvider).isRecording;
      case 'gyroscope':
        return ref.read(gyroProvider).isRecording;
      case 'altitude':
        return ref.read(altProvider).isRecording;
      case 'cell_signal':
        return ref.read(cellProvider).isRecording;
      case 'ambient_light':
        return ref.read(lightProvider).isRecording;
      default:
        return false;
    }
  }
}
