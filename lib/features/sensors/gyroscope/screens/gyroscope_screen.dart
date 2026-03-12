import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/gyro_provider.dart';
import '../../../../app/theme.dart';

class GyroscopeScreen extends ConsumerWidget {
  const GyroscopeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyroState = ref.watch(gyroProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Gyroscope')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            // ── Live chart ──
            SizedBox(
              height: 280,
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
                    Row(
                      children: [
                        Text('Rotation Rate', style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        _buildLegend(),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Expanded(child: _buildChart(gyroState)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Current values
            if (gyroState.recentReadings.isNotEmpty)
              _buildCurrentValues(gyroState),

            const SizedBox(height: AppTheme.spacingMd),

            // Controls
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: gyroState.isRecording
                    ? () => ref.read(gyroProvider.notifier).stopRecording()
                    : () => ref.read(gyroProvider.notifier).startRecording(),
                icon: Icon(gyroState.isRecording ? Icons.stop : Icons.fiber_manual_record, size: 16),
                label: Text(gyroState.isRecording ? 'Stop Recording' : 'Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gyroState.isRecording ? AppTheme.error : AppTheme.primary,
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Sessions
            if (gyroState.sessions.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Sessions', style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              ...gyroState.sessions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  tileColor: AppTheme.surface,
                  leading: const Icon(Icons.screen_rotation, color: AppTheme.warning, size: 20),
                  title: Text('${s.recordCount} samples', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(s.duration != null ? '${s.duration!.inSeconds}s' : 'In progress', style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => ref.read(gyroProvider.notifier).deleteSession(s.id),
                  ),
                ),
              )),
            ] else
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No sessions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot('X', Colors.red),
        const SizedBox(width: 8),
        _dot('Y', Colors.green),
        const SizedBox(width: 8),
        _dot('Z', Colors.blue),
      ],
    );
  }

  Widget _dot(String l, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(l, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      );

  Widget _buildChart(GyroState gyroState) {
    final pts = gyroState.recentReadings;
    if (pts.isEmpty) {
      return const Center(child: Text('Start recording to see live data', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return LineChart(LineChartData(
      minY: -10,
      maxY: 10,
      lineBarsData: [
        _line(pts.map((p) => p.x).toList(), Colors.red),
        _line(pts.map((p) => p.y).toList(), Colors.green),
        _line(pts.map((p) => p.z).toList(), Colors.blue),
      ],
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5,
        getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 0.5),
      ),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 5)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
    ));
  }

  LineChartBarData _line(List<double> vals, Color c) => LineChartBarData(
        spots: vals.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
        isCurved: true,
        curveSmoothness: 0.15,
        color: c,
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
      );

  Widget _buildCurrentValues(GyroState g) {
    final l = g.recentReadings.last;
    return Row(children: [
      _chip('X', l.x, Colors.red),
      const SizedBox(width: 8),
      _chip('Y', l.y, Colors.green),
      const SizedBox(width: 8),
      _chip('Z', l.z, Colors.blue),
    ]);
  }

  Widget _chip(String label, double v, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: [
            Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
            Text('${v.toStringAsFixed(2)} rad/s',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          ]),
        ),
      );
}
