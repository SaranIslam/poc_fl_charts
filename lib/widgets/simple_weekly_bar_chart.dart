import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DayValue {
  const DayValue({
    required this.dayShort,
    required this.dateLabel,
    required this.value,
    this.color,
  });

  final String dayShort; // e.g. 'จ'
  final String dateLabel; // e.g. '10'
  final double value;
  final Color? color;
}

class SimpleWeeklyBarChart extends StatelessWidget {
  const SimpleWeeklyBarChart({
    super.key,
    required this.days,
    this.minY = 0,
    this.maxY,
    this.gridInterval = 2,
    this.barWidth = 18,
    this.groupsSpace = 18,
    this.bottomTitlesReservedSize = 44,
  });

  final List<DayValue> days;
  final double minY;
  final double? maxY;
  final double gridInterval;
  final double barWidth;
  final double groupsSpace;
  final double bottomTitlesReservedSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedMaxY = maxY ?? _roundUp(days.map((d) => d.value).fold<double>(0, (p, v) => v > p ? v : p), gridInterval);

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: d.value,
              width: barWidth,
              color: d.color ?? const Color(0xFF4FA5C8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
          // Always show a tooltip for the single rod in each group
          showingTooltipIndicators: const [0],
        ),
      );
    }
    final barChart = BarChart(
      BarChartData(
        minY: minY,
        maxY: resolvedMaxY,
        barGroups: groups,
        groupsSpace: groupsSpace,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: gridInterval,
          getDrawingHorizontalLine: (v) => FlLine(
            color: theme.colorScheme.onSurface.withOpacity(0.15),
            strokeWidth: 1,
            dashArray: const [6, 6],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: gridInterval,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: bottomTitlesReservedSize,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                final d = days[i];
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.dayShort,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.dateLabel,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: -20,
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            getTooltipColor: (group) => Colors.transparent,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              rod.toY.toStringAsFixed(0),
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            top: const BorderSide(color: Colors.transparent),
            right: const BorderSide(color: Colors.transparent),
            left: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
            bottom: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
          ),
        ),
      ),
      swapAnimationDuration: const Duration(milliseconds: 250),
    );

    return barChart;
  }

  static double _roundUp(double value, double step) {
    if (value <= 0) return step;
    final r = value % step;
    return r == 0 ? value : value + (step - r);
  }
}

// Removed manual painter; relying on FLChart's showingTooltipIndicators with transparent tooltips.

