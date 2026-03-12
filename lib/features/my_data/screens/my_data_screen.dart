import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../shared/constants/sensor_config.dart';
import '../../sensors/gps_traces/screens/gps_traces_screen.dart';
import '../../sensors/step_counter/screens/step_counter_screen.dart';
import '../../sensors/accelerometer/screens/accelerometer_screen.dart';
import '../../sensors/camera_tagging/screens/camera_tagging_screen.dart';
import '../../sensors/altitude/screens/altitude_screen.dart';
import '../../sensors/barometer/screens/barometer_screen.dart';
import '../../sensors/gyroscope/screens/gyroscope_screen.dart';
import '../../sensors/cell_signal/screens/cell_signal_screen.dart';
import '../../sensors/ambient_light/screens/ambient_light_screen.dart';

/// My Data screen — list of all sensor features for navigation.
class MyDataScreen extends StatelessWidget {
  const MyDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('My Data')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        itemCount: SensorConfig.all.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final sensor = SensorConfig.all[index];
          return _SensorListTile(
            config: sensor,
            onTap: () => _navigateToSensor(context, sensor.id),
          );
        },
      ),
    );
  }

  void _navigateToSensor(BuildContext context, String sensorId) {
    Widget screen;
    switch (sensorId) {
      case 'gps':
        screen = const GpsTracesScreen();
      case 'steps':
        screen = const StepCounterScreen();
      case 'accelerometer':
        screen = const AccelerometerScreen();
      case 'camera':
        screen = const CameraTaggingScreen();
      case 'altitude':
        screen = const AltitudeScreen();
      case 'barometer':
        screen = const BarometerScreen();
      case 'gyroscope':
        screen = const GyroscopeScreen();
      case 'cell_signal':
        screen = const CellSignalScreen();
      case 'ambient_light':
        screen = const AmbientLightScreen();
      default:
        // OD mapping — placeholder
        screen = Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Origin-Destination')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction, size: 48, color: AppTheme.disabled),
                const SizedBox(height: 16),
                const Text('Coming soon', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        );
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _SensorListTile extends StatelessWidget {
  final SensorConfig config;
  final VoidCallback onTap;

  const _SensorListTile({required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(config.icon, color: config.color, size: 20),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  Text(
                    config.description,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
