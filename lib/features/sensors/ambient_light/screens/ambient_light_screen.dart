import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/light_provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../app/theme.dart';

class AmbientLightScreen extends ConsumerWidget {
  const AmbientLightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lightState = ref.watch(lightProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Ambient Light')),
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
                  Icon(Icons.light_mode, size: 48, color: AppTheme.warning),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    lightState.currentLux?.toStringAsFixed(0) ?? '--',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const Text('lux', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  const SizedBox(height: AppTheme.spacingMd),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Text(
                      '⚠️ Android only. Light sensor integration requires a platform channel that will be added in the next update.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (lightState.isRecording) ...[
                    const SizedBox(height: AppTheme.spacingMd),
                    Text('${lightState.readingCount} location points recorded',
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
                onPressed: () => _toggle(context, ref, lightState.isRecording),
                icon: Icon(lightState.isRecording ? Icons.stop : Icons.fiber_manual_record, size: 16),
                label: Text(lightState.isRecording ? 'Stop' : 'Start Recording'),
                style: ElevatedButton.styleFrom(backgroundColor: lightState.isRecording ? AppTheme.error : AppTheme.primary),
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
      ref.read(lightProvider.notifier).stopRecording();
    } else {
      final granted = await PermissionService.requestLocation(context);
      if (granted) ref.read(lightProvider.notifier).startRecording();
    }
  }
}
