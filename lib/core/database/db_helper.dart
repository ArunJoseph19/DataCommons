import 'package:sqflite/sqflite.dart';

/// Manages the sqflite database: creation, migrations, and access.
class DbHelper {
  static Database? _database;
  static const _dbName = 'datacommons.db';
  static const _dbVersion = 2;

  /// Get the singleton database instance.
  static Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create all tables on first run.
  static Future<void> _onCreate(Database db, int version) async {
    // GPS Points
    await db.execute('''
      CREATE TABLE gps_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        speed REAL,
        heading REAL,
        accuracy REAL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_gps_session ON gps_points(session_id)');
    await db.execute('CREATE INDEX idx_gps_timestamp ON gps_points(timestamp)');

    // Accelerometer Records
    await db.execute('''
      CREATE TABLE accel_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        z REAL NOT NULL,
        magnitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        context TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_accel_session ON accel_records(session_id)');

    // Gyroscope Records
    await db.execute('''
      CREATE TABLE gyro_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        z REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_gyro_session ON gyro_records(session_id)');

    // Step Records
    await db.execute('''
      CREATE TABLE step_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cumulative_steps INTEGER NOT NULL,
        session_steps INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_step_date ON step_records(date)');

    // Altitude Records
    await db.execute('''
      CREATE TABLE altitude_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        gps_altitude REAL,
        baro_altitude REAL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_alt_session ON altitude_records(session_id)');

    // Barometer Records
    await db.execute('''
      CREATE TABLE baro_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        pressure REAL NOT NULL,
        temperature REAL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_baro_session ON baro_records(session_id)');
    await db.execute('CREATE INDEX idx_baro_timestamp ON baro_records(timestamp)');

    // Cell Signal Records
    await db.execute('''
      CREATE TABLE cell_signal_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        signal_strength INTEGER,
        network_type TEXT,
        carrier TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_cell_session ON cell_signal_records(session_id)');

    // Ambient Light Records
    await db.execute('''
      CREATE TABLE light_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        lux REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_light_session ON light_records(session_id)');

    // Camera Records
    await db.execute('''
      CREATE TABLE camera_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        category TEXT NOT NULL,
        notes TEXT,
        timestamp TEXT NOT NULL,
        firebase_url TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_camera_category ON camera_records(category)');

    // OD (Origin-Destination) Records
    await db.execute('''
      CREATE TABLE od_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        origin_lat REAL NOT NULL,
        origin_lng REAL NOT NULL,
        origin_label TEXT,
        destination_lat REAL NOT NULL,
        destination_lng REAL NOT NULL,
        destination_label TEXT,
        travel_mode TEXT NOT NULL,
        distance_km REAL,
        duration_minutes INTEGER,
        path_json TEXT,
        departure_time TEXT NOT NULL,
        arrival_time TEXT
      )
    ''');

    // Sessions table — tracks recording sessions across all sensors
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        sensor_type TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        record_count INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_sessions_sensor ON sessions(sensor_type)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Destructive migration for development — drop and recreate all tables
    final tables = [
      'gps_points', 'accel_records', 'gyro_records', 'step_records',
      'altitude_records', 'baro_records', 'cell_signal_records',
      'light_records', 'camera_records', 'od_records', 'sessions',
    ];
    for (final t in tables) {
      await db.execute('DROP TABLE IF EXISTS $t');
    }
    await _onCreate(db, newVersion);
  }

  /// Close the database.
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
