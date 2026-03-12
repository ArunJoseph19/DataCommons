import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/models/camera_record.dart';
import '../../../../core/services/data_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../gps_traces/providers/gps_provider.dart';

/// State for camera tagging feature.
class CameraState {
  final List<CameraRecord> records;
  final bool isLoading;

  const CameraState({
    this.records = const [],
    this.isLoading = false,
  });

  CameraState copyWith({
    List<CameraRecord>? records,
    bool? isLoading,
  }) =>
      CameraState(
        records: records ?? this.records,
        isLoading: isLoading ?? this.isLoading,
      );
}

class CameraNotifier extends StateNotifier<CameraState> {
  final DataRepository _repo;
  final LocationService _locationService;
  final ImagePicker _picker = ImagePicker();

  CameraNotifier(this._repo, this._locationService) : super(const CameraState()) {
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    state = state.copyWith(isLoading: true);
    final records = await _repo.getAllCameraRecords();
    state = state.copyWith(records: records, isLoading: false);
  }

  /// Capture a photo from camera and save with location.
  Future<bool> capturePhoto({
    required String category,
    String? notes,
  }) async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return false;

    final position = await _locationService.getCurrentPosition();
    if (position == null) return false;

    final record = CameraRecord(
      imagePath: image.path,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      category: category,
      notes: notes,
      timestamp: DateTime.now(),
    );

    await _repo.insertCameraRecord(record);
    await _loadRecords();
    return true;
  }

  /// Pick a photo from gallery and save with location.
  Future<bool> pickFromGallery({
    required String category,
    String? notes,
  }) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return false;

    final position = await _locationService.getCurrentPosition();
    if (position == null) return false;

    final record = CameraRecord(
      imagePath: image.path,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      category: category,
      notes: notes,
      timestamp: DateTime.now(),
    );

    await _repo.insertCameraRecord(record);
    await _loadRecords();
    return true;
  }

  Future<void> refresh() => _loadRecords();
}

final cameraProvider = StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  return CameraNotifier(
    ref.watch(dataRepositoryProvider),
    ref.watch(locationServiceProvider),
  );
});
