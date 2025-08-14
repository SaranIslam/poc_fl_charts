import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WeeklyGroupedBarChart extends StatelessWidget {
  const WeeklyGroupedBarChart({
    super.key,
    required this.weeks,
    this.maxY,
    this.minY = 0,
    this.gridInterval = 20,
    this.groupsSpace = 28,
    this.barColor,
    this.leftTitleFormatter,
    this.onBarTap,
    this.bottomTitlesReservedSize = 48,
    this.bottomTitlesSpace = 12,
    this.targetBarsPerGroup = 7,
    this.spaceToBarRatio = 0.6,
    this.minBarWidth = 6.0,
    this.averageIncludeZeros = false,
  });

  /// List of week groups to render in order from left to right.
  final List<WeekGroup> weeks;

  /// Optional Y range. If null, it will be computed from data and rounded up to the nearest [gridInterval].
  final double? maxY;
  final double minY;

  /// Horizontal grid step.
  final double gridInterval;

  /// Space between groups.
  final double groupsSpace;

  /// Default color for bars when a bar-specific color isn't provided.
  final Color? barColor;

  /// Format the left titles (Y axis labels).
  final String Function(double value)? leftTitleFormatter;

  /// Optional callback when a bar is tapped.
  final void Function(BarTouchResponse touch)? onBarTap;

  /// Bottom titles reserved height to avoid clipping custom labels.
  final double bottomTitlesReservedSize;

  /// Space between the axis and the bottom title widget.
  final double bottomTitlesSpace;

  /// Desired number of bars per group (will pad with value-0 bars when fewer).
  final int targetBarsPerGroup;

  /// Ratio of space width to bar width inside a group. Used to compute widths to fill the area.
  final double spaceToBarRatio;

  /// Minimum bar width to keep bars visible on small screens.
  final double minBarWidth;

  /// Whether to include zero-value padded bars when computing averages.
  final bool averageIncludeZeros;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final computedMaxY = maxY ?? _computeMaxYRounded(weeks, gridInterval);

    // Chart + overlay painter for per-group average segments and bottom labels
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute plot area width (roughly) to derive each group's area width
        final plotLeftReserved = 40.0;
        final plotWidth = constraints.maxWidth - plotLeftReserved; // approx
        final visibleCount = weeks.length >= 2 ? 2 : weeks.length;
        final totalGap = visibleCount > 1 ? groupsSpace : 0.0;
        final areaWidth = visibleCount > 0 ? (plotWidth - totalGap) / visibleCount : 0.0;

        // Compute dynamic bar width and space so that N bars + spaces exactly fill areaWidth
        final n = targetBarsPerGroup.clamp(1, 7);
        double barW = areaWidth / (n + (n - 1) * spaceToBarRatio);
        if (barW < minBarWidth) {
          barW = minBarWidth;
        }
        double spaceW = (areaWidth - n * barW) / (n - 1 > 0 ? (n - 1) : 1);
        if (spaceW < 0) spaceW = 0;

        // Build groups with padded bars to [n]
        final groups = <BarChartGroupData>[];
        for (var x = 0; x < weeks.length; x++) {
          final week = weeks[x];
          final entries = List<BarEntry>.from(week.entries);
          while (entries.length < n) {
            entries.add(const BarEntry(value: 0));
          }
          final rods = <BarChartRodData>[];
          for (var j = 0; j < entries.length; j++) {
            final entry = entries[j];
            final color = entry.color ?? barColor ?? theme.colorScheme.primary;
            rods.add(
              BarChartRodData(
                toY: entry.value,
                width: barW,
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }
          groups.add(
            BarChartGroupData(
              x: x,
              barRods: rods,
              barsSpace: spaceW,
              showingTooltipIndicators: [],
            ),
          );
        }

        final barChart = BarChart(
          BarChartData(
            minY: minY,
            maxY: computedMaxY,
            barGroups: groups,
            groupsSpace: groupsSpace,
            alignment: BarChartAlignment.spaceBetween,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: gridInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.onSurface.withOpacity(0.15),
                strokeWidth: 1,
                dashArray: [6, 6],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: gridInterval,
                  reservedSize: plotLeftReserved,
                  getTitlesWidget: (value, meta) {
                    final text =
                        leftTitleFormatter?.call(value) ?? value.toStringAsFixed(0);
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(
                        text,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Keep bottom reserved space but render nothing here; we draw labels in overlay.
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: bottomTitlesReservedSize,
                  getTitlesWidget: (value, meta) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            extraLinesData: const ExtraLinesData(horizontalLines: []),
            barTouchData: BarTouchData(
              enabled: onBarTap != null,
              handleBuiltInTouches: true,
              touchCallback: (event, response) {
                if (onBarTap != null && event is FlTapUpEvent && response != null) {
                  onBarTap!(response);
                }
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                top: const BorderSide(color: Colors.transparent),
                right: const BorderSide(color: Colors.transparent),
                left: BorderSide(
                  color: theme.colorScheme.onSurface.withOpacity(0.12),
                ),
                bottom: BorderSide(
                  color: theme.colorScheme.onSurface.withOpacity(0.12),
                ),
              ),
            ),
          ),
          swapAnimationDuration: const Duration(milliseconds: 300),
        );

        return Stack(
          children: [
            barChart,
            // Overlay painter aligns with bars using deterministic geometry
            IgnorePointer(
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _OverlayPainter(
                  weeks: weeks,
                  minY: minY,
                  maxY: computedMaxY,
                  groupBarWidth: barW,
                  barsSpace: spaceW,
                  groupsSpace: groupsSpace,
                  leftReserved: plotLeftReserved,
                  bottomReserved: bottomTitlesReservedSize + bottomTitlesSpace,
                  onSurface: theme.colorScheme.onSurface,
                  primary: theme.colorScheme.primary,
                  averageIncludeZeros: averageIncludeZeros,
                  targetBarsPerGroup: n,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static double _computeMaxYRounded(List<WeekGroup> weeks, double step) {
    double maxY = 0;
    for (final w in weeks) {
      for (final e in w.entries) {
        if (e.value > maxY) maxY = e.value;
      }
      final avg = _computeAverage(w, includeZeros: true) ?? 0;
      if (avg > maxY) maxY = avg;
    }
    final remainder = maxY % step;
    return remainder == 0 ? maxY : maxY + (step - remainder);
  }

  static double? _computeAverage(WeekGroup week, {bool includeZeros = false}) {
    if (week.entries.isEmpty) return null;
    final list = includeZeros
        ? week.entries
        : week.entries.where((e) => e.value > 0).toList();
    if (list.isEmpty) return 0;
    final sum = list.fold<double>(0, (p, e) => p + e.value);
    return sum / list.length;
  }
}

class WeekGroup {
  WeekGroup({
    required this.label,
    required this.entries,
    this.average,
    this.averageColor,
    this.selected = false,
  }) : assert(entries.length <= 7, 'A week can contain at most 7 bars');

  final String label;
  final List<BarEntry> entries;
  final double? average; // If null, computed from entries (zeros excluded by default)
  final Color? averageColor;
  final bool selected;
}

class BarEntry {
  const BarEntry({required this.value, this.color});

  final double value;
  final Color? color;
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.weeks,
    required this.minY,
    required this.maxY,
    required this.groupBarWidth,
    required this.barsSpace,
    required this.groupsSpace,
    required this.leftReserved,
    required this.bottomReserved,
    required this.onSurface,
    required this.primary,
    required this.averageIncludeZeros,
    required this.targetBarsPerGroup,
  });

  final List<WeekGroup> weeks;
  final double minY;
  final double maxY;
  final double groupBarWidth;
  final double barsSpace;
  final double groupsSpace;
  final double leftReserved;
  final double bottomReserved;
  final Color onSurface;
  final Color primary;
  final bool averageIncludeZeros;
  final int targetBarsPerGroup;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) return;

    final plotLeft = leftReserved;
    final plotRight = size.width; // no right reserved
    final plotBottom = size.height - bottomReserved;
    final plotTop = 0.0; // no top reserved

    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    // Exactly two equal group areas with a gap of groupsSpace
    final visibleCount = weeks.length >= 2 ? 2 : weeks.length;
    if (visibleCount == 0) return;

    final totalGap = visibleCount > 1 ? groupsSpace : 0.0;
    final areaWidth = (plotWidth - totalGap) / visibleCount;

    // Area start X positions
    final areaStarts = <double>[];
    double acc = plotLeft;
    for (var i = 0; i < visibleCount; i++) {
      areaStarts.add(acc);
      acc += areaWidth + (i == 0 && visibleCount > 1 ? groupsSpace : 0.0);
    }

    for (var i = 0; i < visibleCount; i++) {
      final week = weeks[i];
      final areaStart = areaStarts[i];
      final areaEnd = areaStart + areaWidth;

      // Average segment spans the entire group area
      final avg = week.average ?? WeeklyGroupedBarChart._computeAverage(
        week,
        includeZeros: averageIncludeZeros,
      );
      if (avg != null && maxY > minY) {
        final t = ((avg - minY) / (maxY - minY)).clamp(0.0, 1.0);
        final y = plotBottom - t * plotHeight;

        final avgPaint = Paint()
          ..color = (week.averageColor ?? primary).withOpacity(0.95)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(areaStart, y),
          Offset(areaEnd, y),
          avgPaint,
        );

        // Avg label near right edge of area
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${avg.toStringAsFixed(0)} avg',
            style: TextStyle(
              color: (week.averageColor ?? primary).withOpacity(0.95),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: areaWidth);
        final labelOffset = Offset(
          areaEnd - textPainter.width,
          y - 20,
        );
        textPainter.paint(canvas, labelOffset);
      }

      // Bottom axis label within the group area
      final isSelected = week.selected;
      final lineColor = onSurface.withOpacity(isSelected ? 0.5 : 0.25);
      final dotColor = onSurface.withOpacity(isSelected ? 0.9 : 0.5);
      final pillBg = isSelected
          ? primary.withOpacity(0.15)
          : onSurface.withOpacity(0.1);
      final pillBorder = isSelected
          ? primary.withOpacity(0.6)
          : onSurface.withOpacity(0.2);
      final pillFg = isSelected ? primary : onSurface.withOpacity(0.85);

      const dotR = 3.0;
      final labelY = plotBottom + bottomReserved * 0.55;

      // Measure text constrained to area width
      final tp = TextPainter(
        text: TextSpan(
          text: week.label,
          style: TextStyle(
            color: pillFg,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: areaWidth);

      const pillHPad = 12.0;
      final pillW = (tp.width + pillHPad * 2).clamp(0.0, areaWidth);

      final pillLeft = areaStart + (areaWidth - pillW) / 2;
      final pillRight = pillLeft + pillW;

      // Dots at exact area edges
      final leftDotCenter = Offset(areaStart + dotR, labelY);
      final rightDotCenter = Offset(areaEnd - dotR, labelY);

      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      // Left line
      final leftLineEndX = (pillLeft - 8).clamp(areaStart + dotR, areaEnd);
      canvas.drawCircle(leftDotCenter, dotR, Paint()..color = dotColor);
      canvas.drawLine(
        Offset(leftDotCenter.dx + dotR, labelY),
        Offset(leftLineEndX, labelY),
        linePaint,
      );

      // Right line
      final rightLineStartX = (pillRight + 8).clamp(areaStart, areaEnd - dotR);
      canvas.drawLine(
        Offset(rightLineStartX, labelY),
        Offset(rightDotCenter.dx - dotR, labelY),
        linePaint,
      );
      canvas.drawCircle(rightDotCenter, dotR, Paint()..color = dotColor);

      // Pill
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset((pillLeft + pillRight) / 2, labelY),
          width: pillW,
          height: 28.0,
        ),
        const Radius.circular(16),
      );
      final bgPaint = Paint()..color = pillBg;
      canvas.drawRRect(rrect, bgPaint);
      final borderPaint = Paint()
        ..color = pillBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(rrect, borderPaint);

      // Text
      final textOffset = Offset(
        (pillLeft + pillRight) / 2 - tp.width / 2,
        labelY - tp.height / 2,
      );
      tp.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return weeks != oldDelegate.weeks ||
        minY != oldDelegate.minY ||
        maxY != oldDelegate.maxY ||
        groupBarWidth != oldDelegate.groupBarWidth ||
        barsSpace != oldDelegate.barsSpace ||
        groupsSpace != oldDelegate.groupsSpace ||
        leftReserved != oldDelegate.leftReserved ||
        bottomReserved != oldDelegate.bottomReserved ||
        onSurface != oldDelegate.onSurface ||
        primary != oldDelegate.primary ||
        averageIncludeZeros != oldDelegate.averageIncludeZeros ||
        targetBarsPerGroup != oldDelegate.targetBarsPerGroup;
  }
}
