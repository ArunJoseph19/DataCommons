import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/gps_provider.dart';
import '../../../../core/models/gps_point.dart';
import '../../../../core/models/session.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/widgets/map_base.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../app/theme.dart';
import '../exporter/gpx_exporter.dart';
import 'package:intl/intl.dart';

class GpsTracesScreen extends ConsumerStatefulWidget {
  const GpsTracesScreen({super.key});

  @override
  ConsumerState<GpsTracesScreen> createState() => _GpsTracesScreenState();
}

class _GpsTracesScreenState extends ConsumerState<GpsTracesScreen> {
  String? _selectedSessionId;
  List<GpsPoint> _selectedPoints = [];
  bool _loadingPoints = false;

  @override
  Widget build(BuildContext context) {
    final gpsState = ref.watch(gpsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('GPS Traces'),
        actions: [
          if (_selectedSessionId != null)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _exportSession(),
              tooltip: 'Export GPX',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Map (top half) ──
          Expanded(
            flex: 5,
            child: _buildMap(gpsState),
          ),

          // ── Divider with recording controls ──
          _buildRecordingBar(gpsState),

          // ── Session list (bottom half) ──
          Expanded(
            flex: 4,
            child: _buildSessionList(gpsState),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(GpsState gpsState) {
    final points = gpsState.isRecording
        ? gpsState.currentPoints
        : _selectedPoints;

    if (points.isEmpty) {
      return Container(
        color: AppTheme.surface,
        child: const Center(
          child: EmptyState(
            icon: Icons.map_outlined,
            title: 'No trace to display',
            subtitle: 'Start recording or select a session below',
          ),
        ),
      );
    }

    final latLngs = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final speeds = points
        .map((p) => p.speed ?? 0.0)
        .toList();

    return MapBase(
      center: latLngs.last,
      zoom: 15.0,
      polylines: [
        speedColoredPolyline(latLngs, speeds),
      ],
      markers: [
        // Start marker
        Marker(
          point: latLngs.first,
          width: 20,
          height: 20,
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
        // End / current marker
        Marker(
          point: latLngs.last,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: gpsState.isRecording ? AppTheme.error : AppTheme.primary,
              shape: BoxShape.circle,
              border: const Border.fromBorderSide(
                BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingBar(GpsState gpsState) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          // Record button
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: gpsState.isRecording ? _stopRecording : _startRecording,
              icon: Icon(
                gpsState.isRecording ? Icons.stop : Icons.fiber_manual_record,
                size: 16,
              ),
              label: Text(gpsState.isRecording ? 'Stop' : 'Record'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    gpsState.isRecording ? AppTheme.error : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),

          // Live stats
          if (gpsState.isRecording) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${gpsState.pointCount} pts',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            if (gpsState.currentPoints.isNotEmpty) ...[
              const SizedBox(width: AppTheme.spacingMd),
              Text(
                '${(gpsState.currentPoints.last.speed ?? 0).toStringAsFixed(1)} m/s',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ] else ...[
            Text(
              '${gpsState.sessions.length} sessions',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionList(GpsState gpsState) {
    final sessions = gpsState.sessions;

    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.route,
        title: 'No sessions yet',
        subtitle: 'Tap Record to start your first GPS trace',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = session.id == _selectedSessionId;

        return _SessionTile(
          session: session,
          isSelected: isSelected,
          isLoading: isSelected && _loadingPoints,
          onTap: () => _selectSession(session),
          onDelete: () => _deleteSession(session.id),
        );
      },
    );
  }

  Future<void> _startRecording() async {
    final granted = await PermissionService.requestLocation(context);
    if (!granted) return;
    await ref.read(gpsProvider.notifier).startRecording();
  }

  Future<void> _stopRecording() async {
    await ref.read(gpsProvider.notifier).stopRecording();
  }

  Future<void> _selectSession(Session session) async {
    if (session.id == _selectedSessionId) {
      setState(() {
        _selectedSessionId = null;
        _selectedPoints = [];
      });
      return;
    }

    setState(() {
      _selectedSessionId = session.id;
      _loadingPoints = true;
    });

    final points = await ref.read(gpsProvider.notifier).getSessionPoints(session.id);

    setState(() {
      _selectedPoints = points;
      _loadingPoints = false;
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: const Text('This will permanently delete this GPS trace and all its data points.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(gpsProvider.notifier).deleteSession(sessionId);
      if (_selectedSessionId == sessionId) {
        setState(() {
          _selectedSessionId = null;
          _selectedPoints = [];
        });
      }
    }
  }

  Future<void> _exportSession() async {
    if (_selectedPoints.isEmpty) return;
    await GpxExporter.exportAndShare(_selectedPoints, _selectedSessionId!);
  }
}

/// Single session tile widget.
class _SessionTile extends StatelessWidget {
  final Session session;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final duration = session.duration;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.06) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.route, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: AppTheme.spacingMd),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(session.startTime),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${timeFormat.format(session.startTime)}'
                    '${duration != null ? '  •  ${_formatDuration(duration)}' : ''}'
                    '  •  ${session.recordCount} pts',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppTheme.textSecondary,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }
}
