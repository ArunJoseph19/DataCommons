import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/camera_provider.dart';
import '../../../../core/models/camera_record.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../app/theme.dart';
import '../../../../shared/widgets/empty_state.dart';

class CameraTaggingScreen extends ConsumerStatefulWidget {
  const CameraTaggingScreen({super.key});

  @override
  ConsumerState<CameraTaggingScreen> createState() => _CameraTaggingScreenState();
}

class _CameraTaggingScreenState extends ConsumerState<CameraTaggingScreen> {
  String _selectedCategory = CameraRecord.categories.first;

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Camera Tagging')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCaptureSheet(),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Tag Photo'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: cameraState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : cameraState.records.isEmpty
              ? const EmptyState(
                  icon: Icons.camera_alt_outlined,
                  title: 'No tagged photos',
                  subtitle: 'Tap the button below to capture a geo-tagged photo',
                )
              : _buildPhotoGrid(cameraState),
    );
  }

  Widget _buildPhotoGrid(CameraState cameraState) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: cameraState.records.length,
      itemBuilder: (context, index) {
        final record = cameraState.records[index];
        return _PhotoCard(record: record);
      },
    );
  }

  void _showCaptureSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tag a Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Category selector
            const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CameraRecord.categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                final label = CameraRecord.categoryLabels[cat] ?? cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickFromGallery();
                    },
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _capturePhoto();
                    },
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMd),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    final granted = await PermissionService.requestCamera(context);
    if (!granted) return;
    final locGranted = await PermissionService.requestLocation(context);
    if (!locGranted) return;

    final success = await ref.read(cameraProvider.notifier).capturePhoto(
          category: _selectedCategory,
        );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo tagged successfully!')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final locGranted = await PermissionService.requestLocation(context);
    if (!locGranted) return;

    final success = await ref.read(cameraProvider.notifier).pickFromGallery(
          category: _selectedCategory,
        );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo tagged successfully!')),
      );
    }
  }
}

class _PhotoCard extends StatelessWidget {
  final CameraRecord record;

  const _PhotoCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, HH:mm');
    final label = CameraRecord.categoryLabels[record.category] ?? record.category;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          Expanded(
            child: File(record.imagePath).existsSync()
                ? Image.file(
                    File(record.imagePath),
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: AppTheme.border,
                    child: const Icon(Icons.broken_image, color: AppTheme.textSecondary),
                  ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateFormat.format(record.timestamp),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
