import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Unified permission request service.
/// Shows a rationale dialog before the system dialog.
class PermissionService {
  /// Request a permission with a rationale dialog.
  /// Returns true if permission was granted.
  static Future<bool> request(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String rationale,
  }) async {
    final status = await permission.status;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) _showSettingsDialog(context, title, rationale);
      return false;
    }

    // Show rationale before system dialog
    if (!context.mounted) return false;
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(rationale),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    final result = await permission.request();

    if (result.isPermanentlyDenied && context.mounted) {
      _showSettingsDialog(context, title, rationale);
    }

    return result.isGranted;
  }

  /// Request location with fine + background.
  static Future<bool> requestLocation(BuildContext context,
      {bool background = false}) async {
    // First get fine location
    final fineGranted = await request(
      context,
      permission: Permission.locationWhenInUse,
      title: 'Location Access',
      rationale:
          'DataCommons needs your location to record GPS traces, tag photos, and map sensor data to real locations.',
    );

    if (!fineGranted) return false;

    if (background) {
      final bgGranted = await request(
        context,
        permission: Permission.locationAlways,
        title: 'Background Location',
        rationale:
            'To keep recording when the app is in the background, DataCommons needs "Always" location access. This can be changed at any time in Settings.',
      );
      return bgGranted;
    }

    return true;
  }

  /// Request camera + photo library.
  static Future<bool> requestCamera(BuildContext context) async {
    return request(
      context,
      permission: Permission.camera,
      title: 'Camera Access',
      rationale:
          'DataCommons uses your camera to capture geo-tagged photos of road conditions, infrastructure, and other urban features.',
    );
  }

  /// Request activity recognition (for step counter).
  static Future<bool> requestActivityRecognition(
      BuildContext context) async {
    return request(
      context,
      permission: Permission.activityRecognition,
      title: 'Activity Recognition',
      rationale:
          'The step counter needs activity recognition permission to count your steps accurately.',
    );
  }

  static void _showSettingsDialog(
      BuildContext context, String title, String rationale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title Required'),
        content: Text(
          '$rationale\n\nThis permission has been denied. '
          'Please enable it in your device Settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
