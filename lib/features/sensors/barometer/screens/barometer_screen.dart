import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/baro_provider.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../app/theme.dart';

class BarometerScreen extends ConsumerWidget {
  const BarometerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baroState = ref.watch(baroProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Barometer')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            // ── Current pressure ──
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
                    baroState.currentPressure?.toStringAsFixed(1) ?? '--',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'hPa (millibars)',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (baroState.isRecording)
                    Text(
                      '${baroState.readingCount} readings',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // ── Pressure chart ──
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
                    Text('Pressure Trend', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppTheme.spacingSm),
                    Expanded(child: _buildChart(baroState)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingLg),

            // ── Controls ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _toggle(context, ref, baroState.isRecording),
                icon: Icon(baroState.isRecording ? Icons.stop : Icons.fiber_manual_record, size: 16),
                label: Text(baroState.isRecording ? 'Stop Recording' : 'Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: baroState.isRecording ? AppTheme.error : AppTheme.primary,
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // ── Session count ──
            Expanded(
              flex: 2,
              child: _buildSessionList(baroState, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BaroState baroState) {
    if (baroState.recentReadings.isEmpty) {
      return const Center(
        child: Text('Start recording to see data', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final readings = baroState.recentReadings;
    final spots = readings.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.pressure))
        .toList();

    final minP = readings.map((r) => r.pressure).reduce((a, b) => a < b ? a : b) - 2;
    final maxP = readings.map((r) => r.pressure).reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        minY: minP,
        maxY: maxP,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: AppTheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 0.5),
        ),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 48),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  Widget _buildSessionList(BaroState baroState, WidgetRef ref) {
    if (baroState.sessions.isEmpty) {
      return const Center(
        child: Text('No recorded sessions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      );
    }

    return ListView.separated(
      itemCount: baroState.sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final session = baroState.sessions[index];
        return ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            side: const BorderSide(color: AppTheme.border),
          ),
          tileColor: AppTheme.surface,
          leading: const Icon(Icons.speed, color: AppTheme.primary, size: 20),
          title: Text('${session.recordCount} readings',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          subtitle: Text(
            session.duration != null ? '${session.duration!.inMinutes}m recording' : 'In progress',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => ref.read(baroProvider.notifier).deleteSession(session.id),
          ),
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool isRecording) async {
    if (isRecording) {
      ref.read(baroProvider.notifier).stopRecording();
    } else {
      final granted = await PermissionService.requestLocation(context);
      if (granted) {
        ref.read(baroProvider.notifier).startRecording();
      }
    }
  }
}
