import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/accel_provider.dart';
import '../../../../app/theme.dart';

class AccelerometerScreen extends ConsumerWidget {
  const AccelerometerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accelState = ref.watch(accelProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Accelerometer'),
        actions: [
          // Sample rate selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune, size: 20),
            tooltip: 'Sample rate',
            onSelected: (hz) => ref.read(accelProvider.notifier).setSampleRate(hz),
            itemBuilder: (_) => [5, 10, 20, 50]
                .map((hz) => PopupMenuItem(
                      value: hz,
                      child: Text('$hz Hz${hz == accelState.sampleRate ? ' ✓' : ''}'),
                    ))
                .toList(),
          ),
        ],
      ),
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
                        Text('Live Data', style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        _buildLegend(),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Expanded(child: _buildLineChart(accelState)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // ── Current values ──
            if (accelState.recentPoints.isNotEmpty)
              _buildCurrentValues(accelState),

            const SizedBox(height: AppTheme.spacingMd),

            // ── Record controls ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: accelState.isRecording
                    ? () => ref.read(accelProvider.notifier).stopRecording()
                    : () => ref.read(accelProvider.notifier).startRecording(),
                icon: Icon(accelState.isRecording ? Icons.stop : Icons.fiber_manual_record, size: 16),
                label: Text(accelState.isRecording ? 'Stop Recording' : 'Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accelState.isRecording ? AppTheme.error : AppTheme.primary,
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // ── Session list ──
            if (accelState.sessions.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Sessions', style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              ...accelState.sessions.map((session) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  tileColor: AppTheme.surface,
                  leading: const Icon(Icons.vibration, color: AppTheme.warning, size: 20),
                  title: Text(
                    '${session.recordCount} samples',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    session.duration != null
                        ? '${session.duration!.inSeconds}s recording'
                        : 'In progress',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => ref.read(accelProvider.notifier).deleteSession(session.id),
                  ),
                ),
              )),
            ] else
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No recorded sessions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
        _legendDot('X', Colors.red),
        const SizedBox(width: 8),
        _legendDot('Y', Colors.green),
        const SizedBox(width: 8),
        _legendDot('Z', Colors.blue),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildLineChart(AccelState accelState) {
    final points = accelState.recentPoints;
    if (points.isEmpty) {
      return const Center(
        child: Text('Start recording to see live data', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return LineChart(
      LineChartData(
        minY: -20,
        maxY: 20,
        lineBarsData: [
          _buildLine(points.map((p) => p.x).toList(), Colors.red),
          _buildLine(points.map((p) => p.y).toList(), Colors.green),
          _buildLine(points.map((p) => p.z).toList(), Colors.blue),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 0.5),
        ),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 10),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  LineChartBarData _buildLine(List<double> values, Color color) {
    return LineChartBarData(
      spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: true,
      curveSmoothness: 0.15,
      color: color,
      barWidth: 1.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildCurrentValues(AccelState accelState) {
    final latest = accelState.recentPoints.last;
    return Row(
      children: [
        _valueChip('X', latest.x, Colors.red),
        const SizedBox(width: 8),
        _valueChip('Y', latest.y, Colors.green),
        const SizedBox(width: 8),
        _valueChip('Z', latest.z, Colors.blue),
        const SizedBox(width: 8),
        _valueChip('Mag', latest.magnitude, AppTheme.textPrimary),
      ],
    );
  }

  Widget _valueChip(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
