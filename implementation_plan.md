# DataCommons — Implementation Plan

> A crowdsourced smartphone sensor data app, built with Flutter (Android-first), Firebase, and OpenStreetMap.

---

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Maps | `flutter_map` + OpenStreetMap tiles | Free, no API key needed |
| Auth | Firebase Auth from day one | Already have Firebase account, skip throwaway local auth |
| Backend | Firestore + Firebase Storage from day one | Wire up with repository abstraction for clean architecture |
| UI | Simple, clean, light theme only | Readable colors, no dark mode toggle, minimal visual clutter |
| Build order | Sequential by priority | GPS → Steps → Accel → Camera → Altitude → Baro → Gyro → OD → Cell → Light |
| Platform | Android only (for now) | Skip iOS-specific concerns in V1 |

---

## Firebase Setup (User Action Required)

> [!IMPORTANT]
> You need to do these steps in the [Firebase Console](https://console.firebase.google.com/) before I can wire up the app. I'll tell you when I need the config files.

### Step 1: Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** → name it `DataCommons`
3. Disable Google Analytics (optional, can add later)
4. Click **Create project**

### Step 2: Add an Android App
1. In your Firebase project, click the **Android icon** to add an app
2. **Package name**: `com.datacommons.app` (we'll use this in the Flutter project)
3. **App nickname**: `DataCommons Android`
4. Click **Register app**
5. **Download `google-services.json`** — you'll place this in `android/app/` later
6. Skip the "Add Firebase SDK" steps (Flutter handles this differently)

### Step 3: Enable Firebase Auth
1. In Firebase Console → **Build** → **Authentication**
2. Click **Get started**
3. Under **Sign-in providers**, enable **Email/Password**

### Step 4: Enable Firestore
1. **Build** → **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (we'll lock down rules later)
4. Pick a region close to your users (e.g. `europe-west2` for UK)

### Step 5: Enable Firebase Storage
1. **Build** → **Storage**
2. Click **Get started**
3. Start in **test mode**
4. Same region as Firestore

---

## Proposed Changes

### Phase 1: Project Foundation

#### [NEW] Flutter project scaffold
- Run `flutter create` with package name `com.datacommons.app`
- Set up the full folder structure from the plan (`lib/app/`, `lib/features/`, `lib/core/`, `lib/shared/`)
- Configure `pubspec.yaml` with all core dependencies

#### Key dependencies (pubspec.yaml)
```yaml
# State management
flutter_riverpod: ^2.5.0
riverpod_annotation: ^2.3.0

# Navigation
go_router: ^14.0.0

# Maps (FREE, no API key)
flutter_map: ^7.0.0
latlong2: ^0.9.0

# Charts
fl_chart: ^0.69.0

# Local DB
sqflite: ^2.3.0
hive: ^2.2.3
hive_flutter: ^1.1.0

# Sensors
sensors_plus: ^5.0.0
geolocator: ^12.0.0
pedometer: ^4.0.0

# Camera
camera: ^0.11.0
image_picker: ^1.1.0

# Permissions
permission_handler: ^11.3.0

# Background
flutter_background_service: ^5.0.0

# Firebase
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0
firebase_storage: ^12.0.0

# Utilities
path_provider: ^2.1.0
share_plus: ^9.0.0
uuid: ^4.4.0
intl: ^0.19.0
connectivity_plus: ^6.0.0
```

#### [NEW] `lib/app/theme.dart`
- Clean, simple light theme
- Neutral palette: whites, light grays, soft blue as accent
- Clean typography using system fonts
- Consistent spacing/padding tokens

#### [NEW] `lib/app/router.dart`
- GoRouter configuration with all route definitions
- Auth redirect logic (if not logged in → login screen)

#### [NEW] `lib/app/providers.dart`
- Root-level Riverpod providers (Firebase instances, DB, Hive)

---

### Phase 2: Core Infrastructure

#### [NEW] `lib/core/database/db_helper.dart`
- sqflite setup with migrations
- One table per sensor type (created on first use)

#### [NEW] `lib/core/database/tables/` (one file per table)
- Table definitions with proper indexes

#### [NEW] `lib/core/services/data_repository.dart`
- Abstract `DataRepository` interface
- `LocalRepository` — reads/writes to sqflite
- `FirebaseRepository` — reads/writes to Firestore
- Riverpod provider that can swap between them

#### [NEW] `lib/core/services/permission_service.dart`
- Unified permission request flow with rationale dialogs
- Settings deep-link on denial

#### [NEW] `lib/core/services/background_service.dart`
- `SensorOrchestrator` — single background isolate managing all active sensors
- Persistent Android foreground notification

#### [NEW] `lib/core/services/location_service.dart`
- Continuous location stream with accuracy filtering

#### [NEW] `lib/shared/widgets/map_base.dart`
- Reusable flutter_map widget with standard controls
- Accepts layers (polylines, markers, circles) as props
- Current location button

#### [NEW] `lib/shared/widgets/chart_base.dart`
- fl_chart wrapper with consistent theming
- Time range selector (1h / 24h / 7d / all)

#### [NEW] `lib/shared/widgets/empty_state.dart`
- Reusable empty state with icon + message

---

### Phase 3: Authentication

#### [NEW] `lib/features/auth/providers/auth_provider.dart`
- Firebase Auth state stream via Riverpod
- Sign up, log in, log out, forgot password methods

#### [NEW] `lib/features/auth/screens/signup_screen.dart`
- Email, password, display name, optional city

#### [NEW] `lib/features/auth/screens/login_screen.dart`
- Email/password login

#### [NEW] `lib/features/auth/widgets/auth_form.dart`
- Shared form widget with validation

---

### Phase 4: Dashboard

#### [NEW] `lib/features/dashboard/screens/dashboard_screen.dart`
- Grid of sensor toggle cards
- Quick stats bar (today's steps, active sensors, data points collected)

#### [NEW] `lib/features/dashboard/widgets/sensor_toggle_card.dart`
- Card with sensor icon, name, toggle switch, status indicator

#### [NEW] `lib/features/dashboard/widgets/active_sensors_bar.dart`
- Horizontal row showing currently active sensors

---

### Phase 5: Sensor Features (built sequentially)

Each sensor feature follows the same pattern:
- `providers/` — Riverpod provider managing the sensor stream
- `models/` — Data model class
- `screens/` — Feature screen with visualization + controls
- `widgets/` — Feature-specific widgets
- `exporter.dart` — Export function for that feature's format

**Priority order:**
1. **GPS Traces** — Most impactful, core feature, polyline on map
2. **Step Counter** — Simple, high user value, daily bar chart
3. **Accelerometer** — Time-series chart, configurable Hz
4. **Camera Tagging** — Photo grid + map pins, category tags
5. **Altitude/DEM** — Elevation profile chart
6. **Barometer** — Pressure line chart + map dot
7. **Gyroscope** — 3-axis chart (similar pattern to accelerometer)
8. **Origin-Destination** — Trip recording, arc map
9. **Cell Signal** — Android-only, native method channel
10. **Ambient Light** — Android-only, limited device support

---

### Phase 6: City-Wide View

#### [NEW] `lib/features/city_view/screens/city_map_screen.dart`
- Full-screen flutter_map
- Layer selector (bottom sheet)
- Shows user's own data pre-community + Firestore community data

#### [NEW] `lib/features/city_view/widgets/layer_selector.dart`
- Toggle layers: GPS density, photo pins, cell signal, etc.

---

### Phase 7: Data Export

#### [NEW] `lib/features/export/export_manager.dart`
- Central export orchestrator
- Date range filtering

#### [NEW] `lib/features/export/exporters/` (one per format)
- `gpx_exporter.dart` — GPS traces
- `csv_exporter.dart` — Accel, gyro, steps, altitude, baro, light
- `geojson_exporter.dart` — Cell signal, OD mapping
- `zip_exporter.dart` — Camera (images + metadata.json)

---

### Phase 8: Profile & Settings

#### [NEW] `lib/features/profile/screens/profile_screen.dart`
- Account details (from Firebase Auth)
- Storage usage (sqflite DB size)
- About / data policy link
- Sign out

---

## Verification Plan

### Phase 1-2: Foundation & Infrastructure
- `flutter analyze` — zero warnings
- `flutter build apk --debug` — builds successfully
- Manual: launch app on Android emulator, confirm it starts without crashing

### Phase 3: Authentication
- Manual: open app → see login screen → sign up with email/password → lands on dashboard
- Manual: log out → log back in → see same profile
- Manual: forgot password → check email arrives

### Phase 4: Dashboard
- Manual: see all sensor cards on dashboard → toggle one on → see it reflected in active sensors bar

### Phase 5: Each Sensor (tested as each is built)
- Manual: toggle sensor on → see data appearing in real-time on the feature screen
- Manual: stop recording → see session listed → tap session → see visualization
- Manual: export data → verify file opens correctly in expected app (e.g. GPX in a map viewer)

### Phase 6-8: City View, Export, Profile
- Manual: open city map → see own data plotted on map
- Manual: export from global export screen → share file
- Manual: check profile shows correct info → sign out works

> [!NOTE]
> Since this is a Flutter mobile app, automated tests (unit/widget tests) can be added incrementally. The primary verification for V1 will be manual testing on an Android emulator or physical device. I'll add unit tests for critical business logic (data repository, exporters) as we build.
