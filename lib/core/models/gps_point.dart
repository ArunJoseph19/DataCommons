/// GPS data point model.
class GpsPoint {
  final int? id;
  final String sessionId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? heading;
  final double? accuracy;
  final DateTime timestamp;

  GpsPoint({
    this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.heading,
    this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'speed': speed,
        'heading': heading,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GpsPoint.fromMap(Map<String, dynamic> map) => GpsPoint(
        id: map['id'] as int?,
        sessionId: map['session_id'] as String,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        altitude: map['altitude'] as double?,
        speed: map['speed'] as double?,
        heading: map['heading'] as double?,
        accuracy: map['accuracy'] as double?,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
