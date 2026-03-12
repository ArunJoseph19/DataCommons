import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app/theme.dart';

/// Time range options for chart filtering.
enum TimeRange {
  oneHour('1h'),
  twentyFourHours('24h'),
  sevenDays('7d'),
  all('All');

  final String label;
  const TimeRange(this.label);
}

/// Reusable chart base widget wrapping fl_chart with consistent theming
/// and a time range selector.
class ChartBase extends StatefulWidget {
  final String title;
  final Widget Function(TimeRange range) chartBuilder;
  final TimeRange initialRange;
  final bool showRangeSelector;

  const ChartBase({
    super.key,
    required this.title,
    required this.chartBuilder,
    this.initialRange = TimeRange.twentyFourHours,
    this.showRangeSelector = true,
  });

  @override
  State<ChartBase> createState() => _ChartBaseState();
}

class _ChartBaseState extends State<ChartBase> {
  late TimeRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialRange;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            if (widget.showRangeSelector) _buildRangeSelector(),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),

        // Chart
        SizedBox(
          height: 220,
          child: widget.chartBuilder(_selectedRange),
        ),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimeRange.values.map((range) {
          final isSelected = range == _selectedRange;
          return GestureDetector(
            onTap: () => setState(() => _selectedRange = range),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
              ),
              child: Text(
                range.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Consistent chart styling helpers.
class ChartStyles {
  ChartStyles._();

  static FlGridData get gridData => FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: false,
        horizontalInterval: null,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppTheme.border,
          strokeWidth: 0.5,
        ),
      );

  static FlTitlesData titlesData({
    String Function(double)? bottomFormatter,
    String Function(double)? leftFormatter,
  }) =>
      FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: bottomFormatter != null,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                bottomFormatter?.call(value) ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            reservedSize: 24,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: leftFormatter != null,
            getTitlesWidget: (value, meta) => Text(
              leftFormatter?.call(value) ?? '',
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            reservedSize: 40,
          ),
        ),
      );

  static FlBorderData get borderData => FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: AppTheme.border),
          left: BorderSide(color: AppTheme.border),
        ),
      );
}
