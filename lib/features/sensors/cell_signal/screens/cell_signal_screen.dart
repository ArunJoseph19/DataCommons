import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cell_provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../app/theme.dart';

class CellSignalScreen extends ConsumerWidget {
  const CellSignalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cellState = ref.watch(cellProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Cell Signal')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.signal_cellular_alt, size: 48, color: AppTheme.primary),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    cellState.latestReading?.signalStrength?.toString() ?? '--',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const Text('dBm', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  const SizedBox(height: AppTheme.spacingMd),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Text(
                      '⚠️ Android only. Signal strength requires TelephonyManager platform channel — location points are being recorded for now.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (cellState.isRecording) ...[
                    const SizedBox(height: AppTheme.spacingMd),
                    Text('${cellState.readingCount} location points recorded',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _toggle(context, ref, cellState.isRecording),
                icon: Icon(cellState.isRecording ? Icons.stop : Icons.fiber_manual_record, size: 16),
                label: Text(cellState.isRecording ? 'Stop' : 'Start Recording'),
                style: ElevatedButton.styleFrom(backgroundColor: cellState.isRecording ? AppTheme.error : AppTheme.primary),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool isRecording) async {
    if (isRecording) {
      ref.read(cellProvider.notifier).stopRecording();
    } else {
      final granted = await PermissionService.requestLocation(context);
      if (granted) ref.read(cellProvider.notifier).startRecording();
    }
  }
}
