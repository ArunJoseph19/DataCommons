/// Camera tagging data record model.
class CameraRecord {
  final int? id;
  final String imagePath;
  final double latitude;
  final double longitude;
  final double? altitude;
  final String category;
  final String? notes;
  final DateTime timestamp;
  final String? firebaseUrl;

  CameraRecord({
    this.id,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.category,
    this.notes,
    required this.timestamp,
    this.firebaseUrl,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'image_path': imagePath,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'category': category,
        'notes': notes,
        'timestamp': timestamp.toIso8601String(),
        'firebase_url': firebaseUrl,
      };

  factory CameraRecord.fromMap(Map<String, dynamic> map) => CameraRecord(
        id: map['id'] as int?,
        imagePath: map['image_path'] as String,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        altitude: map['altitude'] as double?,
        category: map['category'] as String,
        notes: map['notes'] as String?,
        timestamp: DateTime.parse(map['timestamp'] as String),
        firebaseUrl: map['firebase_url'] as String?,
      );

  static const List<String> categories = [
    'pothole',
    'flooding',
    'greenery',
    'infrastructure',
    'lighting',
    'other',
  ];

  static const Map<String, String> categoryLabels = {
    'pothole': '🕳️ Pothole / Road damage',
    'flooding': '🌊 Flooding / Water logging',
    'greenery': '🌳 Urban greenery',
    'infrastructure': '🏚️ Broken infrastructure',
    'lighting': '💡 Lighting issue',
    'other': '📦 Other',
  };
}
