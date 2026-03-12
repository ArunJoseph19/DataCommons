/// Step counter data record model.
class StepRecord {
  final int? id;
  final int cumulativeSteps;
  final int sessionSteps;
  final DateTime timestamp;
  final String date; // YYYY-MM-DD

  StepRecord({
    this.id,
    required this.cumulativeSteps,
    required this.sessionSteps,
    required this.timestamp,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'cumulative_steps': cumulativeSteps,
        'session_steps': sessionSteps,
        'timestamp': timestamp.toIso8601String(),
        'date': date,
      };

  factory StepRecord.fromMap(Map<String, dynamic> map) => StepRecord(
        id: map['id'] as int?,
        cumulativeSteps: map['cumulative_steps'] as int,
        sessionSteps: map['session_steps'] as int,
        timestamp: DateTime.parse(map['timestamp'] as String),
        date: map['date'] as String,
      );
}
