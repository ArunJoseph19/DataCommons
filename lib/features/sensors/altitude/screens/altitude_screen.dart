import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/alt_provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../app/theme.dart';

class AltitudeScreen extends ConsumerWidget {
  const AltitudeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final altState = ref.watch(altProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Altitude / DEM')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            // Current altitude
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
                  Text(
                    altState.currentAltitude?.toStringAsFixed(1) ?? '--',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const Text('meters above sea level', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  if (altState.isRecording) ...[
                    const SizedBox(height: 8),
                    Text('${altState.readingCount} readings', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Elevation profile
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Elevation Profile', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppTheme.spacingSm),
                    Expanded(child: _buildChart(altState)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _toggle(context, ref, altState.isRecording),
                icon: Icon(altState.isRecording ? Icons.stop : Icons.fiber_manual_record, size: 16),
                label: Text(altState.isRecording ? 'Stop Recording' : 'Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: altState.isRecording ? AppTheme.error : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            Expanded(flex: 2, child: _buildSessionList(altState, ref)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(AltState altState) {
    if (altState.recentReadings.isEmpty) {
      return const Center(child: Text('Start recording to see profile', style: TextStyle(color: AppTheme.textSecondary)));
    }
    final readings = altState.recentReadings;
    final spots = readings.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.gpsAltitude))
        .toList();
    final minA = readings.map((r) => r.gpsAltitude).reduce((a, b) => a < b ? a : b) - 5;
    final maxA = readings.map((r) => r.gpsAltitude).reduce((a, b) => a > b ? a : b) + 5;

    return LineChart(LineChartData(
      minY: minA,
      maxY: maxA,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.success,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppTheme.success.withValues(alpha: 0.1)),
        ),
      ],
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 0.5)),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48)),
      ),
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _buildSessionList(AltState a, WidgetRef ref) {
    if (a.sessions.isEmpty) return const Center(child: Text('No sessions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)));
    return ListView.separated(
      itemCount: a.sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final s = a.sessions[i];
        return ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm), side: const BorderSide(color: AppTheme.border)),
          tileColor: AppTheme.surface,
          leading: const Icon(Icons.terrain, color: AppTheme.success, size: 20),
          title: Text('${s.recordCount} readings', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => ref.read(altProvider.notifier).deleteSession(s.id)),
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool isRecording) async {
    if (isRecording) {
      ref.read(altProvider.notifier).stopRecording();
    } else {
      final granted = await PermissionService.requestLocation(context);
      if (granted) ref.read(altProvider.notifier).startRecording();
    }
  }
}
