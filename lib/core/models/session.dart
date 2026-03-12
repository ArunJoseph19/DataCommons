/// Recording session model — tracks a sensor recording session.
class Session {
  final String id;
  final String sensorType;
  final DateTime startTime;
  final DateTime? endTime;
  final int recordCount;

  Session({
    required this.id,
    required this.sensorType,
    required this.startTime,
    this.endTime,
    this.recordCount = 0,
  });

  Duration? get duration => endTime?.difference(startTime);

  bool get isActive => endTime == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sensor_type': sensorType,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'record_count': recordCount,
      };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
        id: map['id'] as String,
        sensorType: map['sensor_type'] as String,
        startTime: DateTime.parse(map['start_time'] as String),
        endTime: map['end_time'] != null
            ? DateTime.parse(map['end_time'] as String)
            : null,
        recordCount: map['record_count'] as int? ?? 0,
      );
}
