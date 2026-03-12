# DataCommons — Full Product Plan

> A crowdsourced smartphone sensor data platform, built in Flutter for iOS & Android.

---

## Table of Contents

1. [Tech Stack](#1-tech-stack)
2. [App Architecture](#2-app-architecture)
3. [Authentication](#3-authentication)
4. [Sensor Features](#4-sensor-features)
5. [Visualisations](#5-visualisations)
6. [City-Wide Data View](#6-city-wide-data-view)
7. [Data Export](#7-data-export)
8. [Permissions Model](#8-permissions-model)
9. [Local Storage Strategy (Pre-Firebase)](#9-local-storage-strategy-pre-firebase)
10. [Firebase Integration (Later Stage)](#10-firebase-integration-later-stage)
11. [Navigation & Screen Map](#11-navigation--screen-map)
12. [Open Questions & Scope for Improvement](#12-open-questions--scope-for-improvement)

---

## 1. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| UI Framework | Flutter (Dart) | Single codebase for iOS & Android |
| State Management | Riverpod 2.x | Reactive, testable, good for sensor streams |
| Navigation | GoRouter | Declarative, deep-link friendly |
| Maps | `google_maps_flutter` | Best Flutter map support; supports polylines, markers, heatmaps |
| Local DB | `sqflite` | Structured sensor data with timestamps |
| Key-Value Store | `hive` | User prefs, settings, toggle states |
| Sensor Access | `sensors_plus` | Accelerometer, gyro, barometer |
| GPS | `geolocator` + `location` | Continuous background GPS traces |
| Pedometer | `pedometer` | Step count |
| Cell Signal | `connectivity_plus` + `network_info_plus` | Signal strength ⚠️ *(see §12)* |
| Ambient Light | `light` package ⚠️ | Limited device support *(see §12)* |
| Camera | `camera` + `image_picker` | Photo capture + metadata |
| File Export | `path_provider` + `share_plus` | Save and share exported files |
| Permissions | `permission_handler` | Unified permission requests across platforms |
| Background Tasks | `flutter_background_service` | Keep sensors running when app is backgrounded |
| Firebase (later) | Firebase Auth, Firestore, Storage, Cloud Functions | Backend sync |

---

## 2. App Architecture

```
lib/
├── main.dart
├── app/
│   ├── router.dart                  # GoRouter route definitions
│   ├── theme.dart                   # Design system: colours, typography, spacing
│   └── providers.dart               # Root-level Riverpod providers
│
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── signup_screen.dart
│   │   │   └── login_screen.dart
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── widgets/
│   │       └── auth_form.dart
│   │
│   ├── dashboard/
│   │   ├── screens/
│   │   │   └── dashboard_screen.dart
│   │   └── widgets/
│   │       ├── sensor_toggle_card.dart
│   │       └── active_sensors_bar.dart
│   │
│   ├── sensors/
│   │   ├── gps_traces/
│   │   ├── accelerometer/
│   │   ├── gyroscope/
│   │   ├── step_counter/
│   │   ├── altitude_dem/
│   │   ├── barometer/
│   │   ├── cell_signal/
│   │   ├── ambient_light/
│   │   ├── camera_tagging/
│   │   └── origin_destination/
│   │   (each folder contains: screen, provider, model, widgets, exporter)
│   │
│   ├── city_view/
│   │   ├── screens/
│   │   │   └── city_map_screen.dart
│   │   └── widgets/
│   │       ├── layer_selector.dart
│   │       └── data_legend.dart
│   │
│   └── export/
│       ├── export_manager.dart
│       └── exporters/
│           ├── gpx_exporter.dart
│           ├── csv_exporter.dart
│           ├── geojson_exporter.dart
│           └── zip_exporter.dart
│
├── core/
│   ├── database/
│   │   ├── db_helper.dart           # sqflite setup and migrations
│   │   └── tables/                  # One file per table definition
│   ├── models/                      # Shared data models
│   ├── services/
│   │   ├── permission_service.dart
│   │   ├── background_service.dart
│   │   └── location_service.dart
│   └── utils/
│       ├── date_utils.dart
│       └── format_utils.dart
│
└── shared/
    ├── widgets/
    │   ├── map_base.dart            # Reusable map component
    │   ├── chart_base.dart
    │   └── empty_state.dart
    └── constants/
        └── sensor_config.dart       # Sensor metadata, labels, icons
```

---

## 3. Authentication

### Screens
- **Sign Up:** Email, password, display name, city (optional for anonymised contribution)
- **Log In:** Email/password
- **Forgot Password**

### Pre-Firebase approach
- Store credentials locally using `flutter_secure_storage`
- Hash password with `bcrypt` (Dart implementation)
- ⚠️ This is insecure for production — real auth must go through Firebase Auth when syncing is added. The local approach is only suitable for the prototype/MVP stage.

### Post-Firebase
- Firebase Authentication (email/password initially, can add Google/Apple Sign-In later)
- Auth state persisted via Firebase SDK automatically

### User Profile stored in Hive
```dart
class UserProfile {
  String id;
  String displayName;
  String email;
  String? city;
  DateTime createdAt;
  Map<String, bool> activeSensors; // which sensors are toggled on
}
```

---

## 4. Sensor Features

Each sensor feature follows the same internal structure:
- A **provider** that manages the sensor stream
- A **model** that defines the data record
- A **local DB table** to persist records
- A **screen** with visualisation + controls
- An **exporter** for that feature's format

---

### 4.1 GPS Traces

**What it collects:** Latitude, longitude, altitude, speed, heading, timestamp — continuously while active.

**Flutter packages:** `geolocator`, `location`

**Data model:**
```dart
class GpsPoint {
  int? id;
  double latitude;
  double longitude;
  double altitude;
  double speed;         // m/s
  double heading;       // degrees
  DateTime timestamp;
  String sessionId;     // groups points into one "trace"
}
```

**Key considerations:**
- Record a new `sessionId` each time the user starts a trace
- Filter out GPS points with accuracy > 20m to reduce noise
- ⚠️ Background GPS on iOS requires `always` location permission — users must explicitly grant this; Apple may reject apps that request it without a clear justification. Carefully craft the permission rationale string.
- ⚠️ Battery drain is significant for continuous GPS. Consider offering a "low frequency" mode (record every 30s vs every 1s).

---

### 4.2 Accelerometer

**What it collects:** X, Y, Z acceleration (m/s²) at a configurable sampling rate.

**Flutter packages:** `sensors_plus`

**Data model:**
```dart
class AccelRecord {
  int? id;
  double x;
  double y;
  double z;
  double magnitude;     // sqrt(x²+y²+z²), useful for derived analysis
  DateTime timestamp;
  String sessionId;
  String? context;      // e.g. "walking", "driving" — user-tagged
}
```

**Key considerations:**
- Sampling at maximum rate produces enormous amounts of data quickly. Default to 10–20 Hz; let users configure it.
- ⚠️ Raw accelerometer data is not very interpretable on its own. Consider adding a basic derived metric like "road roughness score" (RMS of Z-axis while driving) to make it more useful to end users.
- Gravity component (≈9.8 m/s²) needs to be subtracted if you want true linear acceleration — use the `linear_accelerometer` event from `sensors_plus`.

---

### 4.3 Gyroscope

**What it collects:** Angular velocity around X, Y, Z axes (rad/s).

**Flutter packages:** `sensors_plus`

**Data model:**
```dart
class GyroRecord {
  int? id;
  double x;           // pitch rate
  double y;           // roll rate
  double z;           // yaw rate
  DateTime timestamp;
  String sessionId;
}
```

**Key considerations:**
- Gyroscope data is most useful when paired with accelerometer data (combined = IMU data). Consider offering a "combined IMU" recording mode rather than treating them as entirely separate streams.
- ⚠️ Gyroscope drifts over time — this is a known hardware limitation. Long sessions will accumulate error. Fuse with GPS heading where possible.

---

### 4.4 Step Counter

**What it collects:** Cumulative step count and step events with timestamp.

**Flutter packages:** `pedometer`

**Data model:**
```dart
class StepRecord {
  int? id;
  int cumulativeSteps;
  int sessionSteps;         // steps since session start
  DateTime timestamp;
  String date;              // "YYYY-MM-DD" for daily aggregation
}
```

**Key considerations:**
- iOS provides step count via CoreMotion; Android via SensorManager. Both are reliable.
- The `pedometer` package surfaces two streams: `StepCount` (cumulative since reboot) and `PedestrianStatus` (walking/stopped). Both are useful.
- ⚠️ Cumulative steps reset on device reboot, so always calculate session steps as delta from session start, not from device boot.

---

### 4.5 Altitude / DEM (Digital Elevation Model)

**What it collects:** Altitude readings over time and position, to build an elevation profile or contribute to a crowd-sourced DEM.

**Flutter packages:** `geolocator` (includes altitude), `barometer_plugin` for pressure-derived altitude

**Data model:**
```dart
class AltitudeRecord {
  int? id;
  double gpsAltitude;           // metres above sea level from GPS
  double? baroAltitude;         // pressure-derived altitude (more accurate short-term)
  double latitude;
  double longitude;
  DateTime timestamp;
  String sessionId;
}
```

**Key considerations:**
- GPS altitude is notoriously inaccurate (±10–30m vertical error). Barometric altitude is more precise for relative changes but drifts due to weather.
- ⚠️ A true DEM contribution requires referencing altitudes against a datum (e.g. EGM96 geoid). GPS gives ellipsoidal height, not orthometric height (height above sea level). This is a non-trivial geodetic problem — for V1, just store raw values and flag this for later correction.
- Fusing GPS + barometer using a Kalman filter gives the best altitude estimate, but this is complex to implement in Dart. Worth considering for a later version.

---

### 4.6 Barometer

**What it collects:** Atmospheric pressure (hPa) with timestamp and location.

**Flutter packages:** `sensors_plus` (includes barometer on supported devices)

**Data model:**
```dart
class BaroRecord {
  int? id;
  double pressure;        // hPa
  double? temperature;    // celsius, if available
  double latitude;
  double longitude;
  DateTime timestamp;
}
```

**Key considerations:**
- ⚠️ Not all Android or iOS devices have a barometer. Check sensor availability at runtime and show a friendly "not supported on this device" message rather than crashing.
- Barometric readings are affected by the phone being in a pocket vs. held in the open. This is hard to control for, and adds noise. Worth noting in any data documentation.
- Pressure data paired with GPS location has real value for hyperlocal weather modelling — a good use case to communicate to users to motivate contribution.

---

### 4.7 Cell Signal Strength

**What it collects:** Signal strength (dBm or ASU), network type (4G/5G/3G), carrier, location, timestamp.

**Flutter packages:** `connectivity_plus`, `network_info_plus`, potentially a native plugin ⚠️

**Data model:**
```dart
class CellSignalRecord {
  int? id;
  int? signalStrength;       // dBm
  String? networkType;       // "4G", "5G", "3G", "2G"
  String? carrier;
  double latitude;
  double longitude;
  DateTime timestamp;
}
```

**Key considerations:**
- ⚠️ This is the most technically uncertain feature in the plan. Neither `connectivity_plus` nor `network_info_plus` gives raw dBm signal strength. Getting actual signal strength requires platform channel code (native Kotlin/Java for Android, Swift/ObjC for iOS).
- On Android, `TelephonyManager.getSignalStrength()` or `PhoneStateListener` can be used via a method channel.
- On iOS, there is **no public API** for signal strength since iOS 7. Apple removed it. Third-party apps that show signal strength typically use private APIs, which will cause App Store rejection. ⚠️ This feature may need to be **Android-only** or significantly scoped down for iOS.
- Recommend investigating the `flutter_phone_state` or writing a custom native plugin as part of the build.

---

### 4.8 Ambient Light Sensor

**What it collects:** Lux readings with location and timestamp.

**Flutter packages:** `light` (community package) ⚠️

**Data model:**
```dart
class LightRecord {
  int? id;
  double lux;
  double latitude;
  double longitude;
  DateTime timestamp;
}
```

**Key considerations:**
- ⚠️ The `light` Flutter package has limited maintenance and may not work consistently across Android versions. Verify it is still maintained before committing to it. A native Android plugin via method channel may be more reliable.
- ⚠️ iOS does **not** expose the ambient light sensor to third-party apps at all. The screen auto-brightness system uses it internally, but there is no public API. This feature will be **Android-only**. Make this clear in the UI.
- Lux readings are heavily affected by whether the screen is on, screen brightness, and whether the phone is face-up. This is hard to disambiguate without additional context signals.

---

### 4.9 Camera Tagging

**What it collects:** Photos with GPS-tagged metadata, a category tag, and optional notes. Use cases: potholes, broken infrastructure, greenery, flooding, construction.

**Flutter packages:** `camera`, `image_picker`, `geolocator` (for coordinates at time of capture)

**Data model:**
```dart
class CameraRecord {
  int? id;
  String imagePath;           // local file path
  double latitude;
  double longitude;
  double altitude;
  String category;            // "pothole", "flooding", "greenery", "infrastructure", "other"
  String? notes;
  DateTime timestamp;
  String? firebaseStorageUrl; // populated post-Firebase sync
}
```

**Categories (initial set):**
- 🕳️ Pothole / Road damage
- 🌊 Flooding / Water logging
- 🌳 Urban greenery
- 🏚️ Broken infrastructure
- 💡 Lighting (dark area, broken streetlight)
- 📦 Other (free-tag)

**Key considerations:**
- Store images locally in the app's document directory initially.
- ⚠️ Images will consume significant storage quickly. Set a clear limit per user (e.g. max 500 photos locally) and prompt upload to Firebase Storage when syncing is added.
- Strip any EXIF data beyond GPS coords before storing, to protect user privacy.
- ⚠️ Category taxonomy is opinionated and may not cover all use cases. Consider allowing free-text tags as a fallback, and reviewing the taxonomy with real users before launch.

---

### 4.10 Origin-Destination (OD) Mapping

**What it collects:** Start point, end point, mode of travel, duration, distance, and path of a commute or trip.

**Flutter packages:** `geolocator`, `google_maps_flutter`

**Data model:**
```dart
class ODRecord {
  int? id;
  double originLat;
  double originLng;
  String? originLabel;          // user-provided label, e.g. "Home"
  double destinationLat;
  double destinationLng;
  String? destinationLabel;     // e.g. "Work"
  String travelMode;            // "walk", "cycle", "car", "bus", "train", "other"
  double distanceKm;
  int durationMinutes;
  List<LatLng> path;            // stored as JSON string in DB
  DateTime departureTime;
  DateTime arrivalTime;
}
```

**Key considerations:**
- The user manually marks "start trip" and "end trip", which triggers GPS recording for that session.
- Path is derived from GPS trace, snapped optionally to road network. ⚠️ Road snapping requires the Google Roads API, which has cost implications — leave this as an optional enhancement.
- ⚠️ OD data is sensitive. Even anonymised commute patterns can identify individuals (home → work at consistent times). Ensure users are clearly informed and consider offering a fuzzing option (blur origin/destination by 200m radius).

---

## 5. Visualisations

Each sensor screen has its own dedicated visualisation. A reusable map widget and chart widget are used across features.

| Feature | Visualisation | Package(s) |
|---|---|---|
| GPS Traces | Polyline on Google Map, coloured by speed | `google_maps_flutter` |
| Accelerometer | 3-line time-series chart (X, Y, Z) + magnitude | `fl_chart` |
| Gyroscope | 3-axis animated line chart | `fl_chart` |
| Step Counter | Daily bar chart (7-day / 30-day view) | `fl_chart` |
| Altitude / DEM | Elevation profile line chart (x = distance, y = altitude) | `fl_chart` |
| Barometer | Line chart of pressure over time + location dot on map | `fl_chart` + `google_maps_flutter` |
| Cell Signal | Colour-coded heatmap on map (green = strong, red = weak) | `google_maps_flutter` (custom tile overlay) ⚠️ |
| Ambient Light | Area chart of lux over time | `fl_chart` |
| Camera Tagging | Photo grid + category-filtered pins on map | `google_maps_flutter` + `cached_network_image` |
| Origin-Destination | Arc map: curved lines from origin to destination | `google_maps_flutter` (custom painter) |

**Shared Map Component (`map_base.dart`):**
- Base Google Map with standard controls
- Toggle layers on/off
- Current location button
- Accepts a list of layers (polylines, markers, heatmap data, arcs) as props

**Shared Chart Component (`chart_base.dart`):**
- Wraps `fl_chart` with consistent theming
- Time range selector (1h / 24h / 7d / all)
- Empty state handling

**Key considerations:**
- ⚠️ `google_maps_flutter` requires a Google Maps API key. This needs billing enabled on a Google Cloud project, and keys must be kept out of source control. Use environment variables or `--dart-define` flags.
- ⚠️ A true heatmap for cell signal is not natively supported by `google_maps_flutter`. The most practical approach is to cluster points into a grid and colour the map tiles, or use a custom `Canvas` painter overlay. This is doable but non-trivial.
- OD arc map requires drawing curved lines between point pairs. This can be done with a custom `CustomPainter` that draws Bezier curves on a map overlay — worth researching existing Flutter implementations before building from scratch.

---

## 6. City-Wide Data View

A dedicated screen where users can see aggregated, anonymised data contributed by all users across the city.

### Screen: City Map (`city_map_screen.dart`)

**Features:**
- Full-screen Google Map defaulting to the user's city
- Layer selector panel (bottom sheet or side drawer):
  - GPS trace density
  - Pothole / infrastructure photo pins
  - Cell signal heatmap
  - Noise / light pollution heatmap
  - OD flow arcs
  - Elevation contours
- Contribution counter ("X data points collected in this city today")
- Date range filter

**Pre-Firebase approach:**
- Show only the current user's own data, labelled as "Your Data"
- When Firebase is added, pull aggregated community data from Firestore

**Key considerations:**
- ⚠️ Without Firebase, a true "city-wide" view is impossible — you only have the local user's data. Be transparent about this in the UI during the pre-Firebase phase. A placeholder state ("Be one of the first contributors — your data will appear here once the community grows") is good UX.
- ⚠️ When real community data is added, privacy becomes critical. Never show individual GPS traces from other users — only aggregate or cluster them. OD data should always be anonymised.

---

## 7. Data Export

Each feature has one designated export format, chosen for widest compatibility and domain standard.

| Feature | Format | Why |
|---|---|---|
| GPS Traces | `.gpx` | Industry standard for GPS track sharing; works with Google Earth, Strava, QGIS |
| Accelerometer | `.csv` | Simple tabular format; works with Excel, Python, R |
| Gyroscope | `.csv` | Same as above |
| Step Counter | `.csv` | Daily aggregated step counts |
| Altitude / DEM | `.csv` | Lat/lng/altitude rows; importable to QGIS or MATLAB |
| Barometer | `.csv` | Timestamped pressure + location |
| Cell Signal | `.geojson` | Spatial format with signal strength properties; QGIS-compatible |
| Ambient Light | `.csv` | Timestamped lux + location |
| Camera Tagging | `.zip` (images + `metadata.json`) | Photos with a JSON manifest of all metadata |
| OD Mapping | `.geojson` | Standard for OD flow data; compatible with QGIS, kepler.gl |

### Export Flow

1. User taps "Export" on a feature screen or from a global Export screen
2. App queries local DB for all records of that type (or date-range filtered)
3. Exporter class generates the file and writes it to a temp directory via `path_provider`
4. `share_plus` opens the native share sheet (iOS: AirDrop/Files/email; Android: share intent)

### GPX Exporter (example structure)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="DataCommons">
  <trk>
    <name>Session 2024-11-01 08:32</name>
    <trkseg>
      <trkpt lat="51.5074" lon="-0.1278">
        <ele>24.5</ele>
        <time>2024-11-01T08:32:00Z</time>
        <speed>1.4</speed>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
```

**Key considerations:**
- ⚠️ Large datasets (e.g. a week of continuous GPS) can produce very large files. Consider adding a date-range filter to the export UI so users don't accidentally export everything at once.
- ⚠️ The `.zip` export for camera tagging will require bundling potentially large image files. On older devices with limited RAM, this could cause memory issues. Use chunked writing and test on low-spec devices.

---

## 8. Permissions Model

### Principle
Request permissions **only when the user toggles a sensor on** — not at app launch. This is both best practice and required by Apple/Google review guidelines.

### Permission map

| Sensor | Permission Required | iOS | Android |
|---|---|---|---|
| GPS Traces | Location (Always for background) | ✅ — needs justification | ✅ |
| Accelerometer | None | — | — |
| Gyroscope | None | — | — |
| Step Counter | Activity Recognition | ✅ (Motion & Fitness) | ✅ (ACTIVITY_RECOGNITION) |
| Altitude | Location | ✅ | ✅ |
| Barometer | None | — | — |
| Cell Signal | Location + Phone State | ✅ (limited) | ✅ |
| Ambient Light | None (Android) / N/A (iOS) | ❌ not available | — |
| Camera Tagging | Camera + Location + Photo Library | ✅ | ✅ |
| OD Mapping | Location (Always) | ✅ | ✅ |

### Implementation
- Use `permission_handler` package for a unified API
- Show a pre-permission rationale dialog **before** the system dialog — explain why the permission is needed in plain language
- If permission is denied, disable the toggle and show a persistent inline message with a "Go to Settings" deep link
- On iOS, "Location Always" is a two-step grant: user must first grant "While Using", then manually upgrade to "Always" in Settings. Handle this gracefully in the UI.

---

## 9. Local Storage Strategy (Pre-Firebase)

### sqflite — Sensor Data
One table per sensor type. Common schema pattern:

```sql
CREATE TABLE gps_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  altitude REAL,
  speed REAL,
  heading REAL,
  timestamp TEXT NOT NULL    -- ISO 8601
);

CREATE INDEX idx_gps_session ON gps_points(session_id);
CREATE INDEX idx_gps_timestamp ON gps_points(timestamp);
```

### Hive — App State & Preferences
- User profile
- Sensor toggle states
- Export history (file paths, dates)
- App settings (sampling rates, map style, theme)

### Data Retention
- ⚠️ Without a sync mechanism, all data is at risk if the user uninstalls the app or switches devices. Clearly communicate this to users in V1.
- Consider adding a "backup to file" option (export everything to a zip) as a stopgap before Firebase sync.
- Set a configurable local storage limit (e.g. warn at 500MB) to prevent the app consuming excessive device storage.

---

## 10. Firebase Integration (Later Stage)

This is a planned second phase — do not build for it now, but architect the local code to make migration easy.

### Plan

| Firebase Service | Usage |
|---|---|
| Firebase Auth | Replace local auth; email/password + Google/Apple |
| Firestore | Store sensor metadata and aggregated records |
| Firebase Storage | Store camera images (`.jpg` files) |
| Cloud Functions | Aggregate data for city-wide view; privacy filtering |
| Firebase Analytics | Usage tracking (opt-in) |

### Migration Strategy
- Wrap all DB calls behind a `DataRepository` interface with two implementations: `LocalRepository` (sqflite) and `FirebaseRepository`
- When Firebase is added, swap the implementation via Riverpod's `override` — the rest of the app doesn't change
- On first sync, batch-upload all local records to Firestore

### Firestore Data Structure (draft)
```
/users/{userId}
  /sessions/{sessionId}
    /gps_points/{pointId}
    /accel_records/{recordId}
  /od_trips/{tripId}
  /camera_records/{recordId}

/city_aggregates/{cityId}
  /cell_signal_grid/{gridId}
  /photo_pins/{pinId}
```

**Key considerations:**
- ⚠️ Firestore read/write costs can escalate quickly with continuous sensor data. GPS at 1Hz for 1 hour = 3,600 writes per session per user. At scale, this is expensive. Batch writes (group 100 points into one document) to reduce costs.
- ⚠️ Define Firestore security rules carefully from day one. Default open rules are a major security risk.

---

## 11. Navigation & Screen Map

```
App
├── Onboarding (first launch only)
│   └── Sign Up / Log In
│
├── Bottom Nav
│   ├── Dashboard (Home)
│   │   ├── Sensor toggle cards (one per feature)
│   │   └── Quick stats (today's steps, active sensors, data points)
│   │
│   ├── My Data
│   │   ├── Feature list → individual feature screens
│   │   │   ├── GPS Traces Screen (map + session list)
│   │   │   ├── Accelerometer Screen (chart + session list)
│   │   │   ├── Gyroscope Screen
│   │   │   ├── Step Counter Screen
│   │   │   ├── Altitude Screen
│   │   │   ├── Barometer Screen
│   │   │   ├── Cell Signal Screen
│   │   │   ├── Ambient Light Screen
│   │   │   ├── Camera Tagging Screen
│   │   │   └── OD Mapping Screen
│   │   └── Export screen (per feature or bulk)
│   │
│   ├── City Map
│   │   └── Layer-toggled aggregated city view
│   │
│   └── Profile
│       ├── Account details
│       ├── Storage usage
│       ├── Notification settings
│       └── About / Data policy
```

---

## 12. Open Questions & Scope for Improvement

These are areas of genuine uncertainty or known limitations that need further investigation or design decisions before or during build.

---

### ⚠️ Platform Limitations

**Cell signal strength on iOS**
The biggest platform constraint in this plan. Apple removed public APIs for signal strength after iOS 7. Any implementation on iOS would require private APIs (App Store rejection risk) or native entitlements not available to third-party developers. **Recommendation:** Scope cell signal as Android-only for V1, or remove it entirely and revisit.

**Ambient light on iOS**
No public ambient light API exists for iOS third-party apps. This feature should be documented as Android-only from the start, with clear UI affordances for iOS users explaining why it's unavailable.

**Background location on iOS**
Apple's review process scrutinises apps that request "Always On" location permission. You will need a clear, well-articulated reason in the App Store description and during review. Consider making background GPS opt-in with a strong user explanation.

---

### ⚠️ Data Volume & Performance

**Sampling rates are not defined for most sensors**
Accelerometer, gyroscope, and barometer can all produce data at 10–100Hz. There are no default sampling rates specified in this plan. These need to be decided and tested carefully — too fast causes storage and battery problems, too slow reduces data quality. Configurable rates are the right approach but add UI complexity.

**No data compression strategy**
Raw sensor data stored in sqflite without compression will consume significant storage. Consider delta encoding (only store changes from last reading) or downsampling old data over time.

---

### ⚠️ Privacy & Ethics

**OD data de-anonymisation risk**
Origin-destination commute data, even stripped of names, is highly re-identifiable. A user who commutes from the same suburb to the same office every day at the same time can be easily profiled. This needs a formal privacy review before any community sharing is enabled. Spatial fuzzing (blurring start/end by a random offset) is a minimum mitigation.

**Camera photos and location**
Photos taken with location data are sensitive. The app should have a clear, prominent data policy explaining what is stored, what is shared, and what is not.

**Informed consent model**
The current plan uses per-sensor toggles as implicit consent. For a research-grade data collection app, a more formal consent flow (explicit opt-in to sharing anonymised data, ability to delete all contributed data) would make the platform more credible to academic and public sector partners.

---

### ⚠️ Technical Architecture

**Repository abstraction not yet detailed**
The plan mentions a `DataRepository` interface for Firebase migration but doesn't specify its method signatures. Defining this interface early prevents technical debt when migrating.

**Background service coordination**
Multiple sensors running simultaneously in the background is complex to manage. `flutter_background_service` handles one service, but coordinating GPS, accelerometer, barometer etc. simultaneously without excessive battery drain requires careful architecture. A single `SensorOrchestrator` service that manages all active sensors from one background isolate is likely better than one background service per sensor.

**Error handling and sensor unavailability**
No error handling strategy is defined. Sensors can fail, permissions can be revoked mid-session, GPS can lose signal. Each sensor provider needs graceful degradation and user-visible status.

---

### ⚠️ UX & Product

**Onboarding experience is not designed**
First-time users need to understand what the app does, why data collection matters, and which sensors to enable. A well-designed onboarding flow is important for conversion and trust, but is not specified in this plan.

**No notification strategy**
For background collection, users benefit from persistent notifications showing which sensors are active (required on Android for foreground services anyway). The content and design of these notifications is not defined.

**City selection**
The city-wide view assumes a known city. How is the user's city determined — by GPS, by manual selection, or by IP? This affects both the City Map screen and any future Firestore data partitioning.

**Gamification / contribution incentives**
Crowdsourced platforms benefit from social proof and contribution incentives. A leaderboard, contribution streak, or milestone badges could drive retention. Not in scope for V1, but worth considering in the product roadmap.

---

*Last updated: March 2026 — Pre-build planning phase*
