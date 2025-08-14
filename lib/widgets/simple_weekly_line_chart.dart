import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'simple_weekly_bar_chart.dart' show DayValue;

class SimpleWeeklyLineChart extends StatelessWidget {
  const SimpleWeeklyLineChart({
    super.key,
    required this.days,
    this.avgY,
    this.minY = 0,
    this.maxY,
    this.gridInterval = 2,
    this.topPaddingIntervals = 0.5,
    this.leftTitlesReservedSize = 40,
    this.bottomTitlesReservedSize = 44,
  });

  final List<DayValue> days;
  final double? avgY;
  final double minY;
  final double? maxY;
  final double gridInterval;
  final double topPaddingIntervals;
  final double leftTitlesReservedSize;
  final double bottomTitlesReservedSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseMax = days.map((e) => e.value).fold<double>(0, (p, v) => v > p ? v : p);
    final resolvedMaxY = (maxY ?? _roundUp(baseMax, gridInterval));

    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      spots.add(FlSpot(i.toDouble(), days[i].value));
    }

    final gridColor = theme.colorScheme.onSurface.withOpacity(0.18);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: resolvedMaxY,
        minX: 0,
        maxX: (days.length - 1).toDouble(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: gridInterval,
          checkToShowHorizontalLine: (v) => true,
          getDrawingHorizontalLine: (value) => FlLine(
            color: gridColor,
            strokeWidth: 1,
            dashArray: const [6, 6],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            axisNameSize: 40,
            axisNameWidget: Align(
              alignment: Alignment.topLeft,
              child: Text(
                'hours',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            sideTitles: const SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: leftTitlesReservedSize,
              interval: gridInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
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
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
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
        borderData: FlBorderData(
          show: true,
          border: Border(
            top: const BorderSide(color: Colors.transparent),
            right: const BorderSide(color: Colors.transparent),
            left: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
            bottom: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: const Color(0xFF4FA5C8),
            barWidth: 2,
            dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF4FA5C8),
                strokeWidth: 0,
              );
            }),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            // Ensure visible line at top value (e.g., 10)
            HorizontalLine(
              y: resolvedMaxY,
              color: gridColor,
              strokeWidth: 1,
              dashArray: const [6, 6],
            ),
            if (avgY != null)
              HorizontalLine(
                y: avgY!,
                color: Colors.white.withOpacity(0.85),
                strokeWidth: 1,
                dashArray: const [6, 6],
              ),
          ],
        ),
      ),
    );
  }

  static double _roundUp(double value, double step) {
    if (value <= 0) return step;
    final r = value % step;
    return r == 0 ? value : value + (step - r);
  }
}

