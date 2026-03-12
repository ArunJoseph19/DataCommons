import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';

/// Manages the Android foreground service for persistent sensor recording.
///
/// When any sensor is toggled on, the foreground service starts and keeps
/// the app alive even when minimised. The service shows a persistent
/// notification so Android doesn't kill the process.
class BackgroundServiceHelper {
  static final _service = FlutterBackgroundService();

  /// Initialise the background service — call once at app start.
  static Future<void> init() async {
    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        onStart: _onStart,
        notificationChannelId: 'datacommons_sensor_channel',
        initialNotificationTitle: 'DataCommons',
        initialNotificationContent: 'Sensors are recording…',
        foregroundServiceNotificationId: 8888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
    );
  }

  /// Start the foreground service (call when first sensor is toggled on).
  static Future<void> start() async {
    final running = await _service.isRunning();
    if (!running) {
      await _service.startService();
    }
  }

  /// Stop the foreground service (call when last sensor is toggled off).
  static Future<void> stop() async {
    final running = await _service.isRunning();
    if (running) {
      _service.invoke('stopService');
    }
  }

  /// Update the notification text (e.g. "3 sensors active").
  static void updateNotification(int activeSensorCount) {
    if (activeSensorCount > 0) {
      _service.invoke('updateNotification', {
        'title': 'DataCommons',
        'content': '$activeSensorCount sensor${activeSensorCount > 1 ? 's' : ''} recording…',
      });
    }
  }

  /// Check if service is running.
  static Future<bool> get isRunning => _service.isRunning();
}

// ─── Service entry points (run in isolate) ───

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) {
      service.stopSelf();
    });

    service.on('updateNotification').listen((event) {
      if (event != null) {
        service.setForegroundNotificationInfo(
          title: event['title'] ?? 'DataCommons',
          content: event['content'] ?? 'Recording…',
        );
      }
    });

    // Set as foreground — shows the persistent notification
    await service.setAsForegroundService();
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
