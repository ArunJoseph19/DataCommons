import 'package:flutter/material.dart';

/// Sensor metadata — icons, labels, descriptions for all sensors.
class SensorConfig {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const SensorConfig({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  static const List<SensorConfig> all = [
    SensorConfig(
      id: 'gps',
      label: 'GPS Traces',
      description: 'Record location, speed & heading',
      icon: Icons.route,
      color: Color(0xFF3B82F6),
    ),
    SensorConfig(
      id: 'steps',
      label: 'Step Counter',
      description: 'Track daily step count',
      icon: Icons.directions_walk,
      color: Color(0xFF22C55E),
    ),
    SensorConfig(
      id: 'accelerometer',
      label: 'Accelerometer',
      description: 'Measure acceleration (X, Y, Z)',
      icon: Icons.vibration,
      color: Color(0xFFF59E0B),
    ),
    SensorConfig(
      id: 'camera',
      label: 'Camera Tagging',
      description: 'Photo capture with GPS tags',
      icon: Icons.camera_alt,
      color: Color(0xFFEF4444),
    ),
    SensorConfig(
      id: 'altitude',
      label: 'Altitude / DEM',
      description: 'Elevation tracking',
      icon: Icons.terrain,
      color: Color(0xFF8B5CF6),
    ),
    SensorConfig(
      id: 'barometer',
      label: 'Barometer',
      description: 'Atmospheric pressure readings',
      icon: Icons.speed,
      color: Color(0xFF06B6D4),
    ),
    SensorConfig(
      id: 'gyroscope',
      label: 'Gyroscope',
      description: 'Angular velocity (X, Y, Z)',
      icon: Icons.threesixty,
      color: Color(0xFFEC4899),
    ),
    SensorConfig(
      id: 'od',
      label: 'Origin-Destination',
      description: 'Trip recording with routes',
      icon: Icons.swap_calls,
      color: Color(0xFF14B8A6),
    ),
    SensorConfig(
      id: 'cell_signal',
      label: 'Cell Signal',
      description: 'Network strength mapping',
      icon: Icons.signal_cellular_alt,
      color: Color(0xFFF97316),
    ),
    SensorConfig(
      id: 'ambient_light',
      label: 'Ambient Light',
      description: 'Light level (lux) readings',
      icon: Icons.light_mode,
      color: Color(0xFFEAB308),
    ),
  ];
}
