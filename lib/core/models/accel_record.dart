import 'dart:math';

/// Accelerometer data record model.
class AccelRecord {
  final int? id;
  final String sessionId;
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;
  final String? context;

  AccelRecord({
    this.id,
    required this.sessionId,
    required this.x,
    required this.y,
    required this.z,
    double? magnitude,
    required this.timestamp,
    this.context,
  }) : magnitude = magnitude ?? sqrt(x * x + y * y + z * z);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'x': x,
        'y': y,
        'z': z,
        'magnitude': magnitude,
        'timestamp': timestamp.toIso8601String(),
        'context': context,
      };

  factory AccelRecord.fromMap(Map<String, dynamic> map) => AccelRecord(
        id: map['id'] as int?,
        sessionId: map['session_id'] as String,
        x: map['x'] as double,
        y: map['y'] as double,
        z: map['z'] as double,
        magnitude: map['magnitude'] as double,
        timestamp: DateTime.parse(map['timestamp'] as String),
        context: map['context'] as String?,
      );
}
