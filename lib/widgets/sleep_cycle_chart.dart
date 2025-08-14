import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SleepSample {
  const SleepSample({required this.time, required this.level});
  final DateTime time; // timestamp
  final double level; // numeric y-value
}

class SleepPoint {
  const SleepPoint({required this.state, required this.time});
  final int state; // 0..2 (e.g., 0: deep, 1: light, 2: awake)
  final DateTime time;
}

class TimeRange {
  const TimeRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

class SleepCycleChart extends StatefulWidget {
  const SleepCycleChart({
    super.key,
    this.samples = const [],
    this.sleeps = const [],
    this.remWindows = const [],
    this.remLevelRange,
    this.highlightTime,
    this.minY = 0,
    this.maxY = 2,
  });

  final List<SleepSample> samples; // optional numeric
  final List<SleepPoint> sleeps; // discrete states
  final List<TimeRange> remWindows;
  final (double y1, double y2)? remLevelRange; // optional horizontal REM band
  final DateTime? highlightTime;
  final double minY;
  final double maxY;

  @override
  State<SleepCycleChart> createState() => _SleepCycleChartState();
}

class _SleepCycleChartState extends State<SleepCycleChart> {
  DateTime? _touchedTime;

  @override
  Widget build(BuildContext context) {
    // choose source
    final samples = widget.sleeps.isNotEmpty
        ? _expandDiscreteToSteps(widget.sleeps)
        : widget.samples;
    if (samples.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final sorted = [...samples]..sort((a, b) => a.time.compareTo(b.time));
    final start = sorted.first.time;
    final end = sorted.last.time;
    // totalMinutes replaced by lastMinuteInt below for labels and bounds

    double toX(DateTime t) => (t.difference(start).inMinutes).toDouble();

    final spots = sorted.map((s) => FlSpot(toX(s.time), s.level)).toList();

    // Always-on highlight indicator (custom dot + dashed vertical)
    final showing = <ShowingTooltipIndicators>[];
    if (widget.highlightTime != null) {
      final hx = toX(
        widget.highlightTime!.isBefore(start) ? start : widget.highlightTime!,
      );
      FlSpot? closest;
      for (final sp in spots) {
        if (closest == null || (sp.x - hx).abs() < (closest.x - hx).abs()) {
          closest = sp;
        }
      }
      if (closest != null) {
        final bar = LineChartBarData(spots: spots);
        showing.add(ShowingTooltipIndicators([LineBarSpot(bar, 0, closest)]));
      }
    }

    // Vertical REM windows will be drawn via a custom painter to support gradient fills.

    final horizontalRem = widget.remLevelRange == null
        ? const <HorizontalRangeAnnotation>[]
        : [
            HorizontalRangeAnnotation(
              y1: widget.remLevelRange!.$1,
              y2: widget.remLevelRange!.$2,
              color: const Color(0xFF7EE6D8).withOpacity(0.10),
            ),
          ];

    // Build x-axis allowed tick minutes: start, end, and each full hour in between
    final lastMinuteInt = end.difference(start).inMinutes;
    final allowedTicks = <int>{0, lastMinuteInt};
    var offset = (60 - start.minute) % 60; // minutes to next full hour
    // avoid crowding if hour tick too close to the start label
    if (offset > 0 && offset < 8) offset += 60;
    for (var m = offset; m < lastMinuteInt; m += 60) {
      allowedTicks.add(m);
    }

    const double bottomReserved = 44; // keep labels from clipping

    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: lastMinuteInt.toDouble(),
        minY: widget.minY,
        maxY: widget.maxY,
        showingTooltipIndicators: showing,
        gridData: const FlGridData(show: false),
        // Only keep horizontal band in native annotations; draw vertical ranges with a custom painter for gradient support
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: const [],
          horizontalRangeAnnotations: horizontalRem,
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: bottomReserved,
              interval: 1, // we filter by a precomputed allow-list
              getTitlesWidget: (value, meta) {
                final minutes = value.round();
                if (!allowedTicks.contains(minutes)) return const SizedBox.shrink();

                final isFirst = minutes == 0;
                final isLast = minutes == lastMinuteInt;
                final time = isLast ? end : start.add(Duration(minutes: minutes));
                final label = (isFirst || isLast)
                    ? _fmt(time, withMinutes: true)
                    : _fmt(time, withMinutes: false);
                final color = isFirst
                    ? const Color(0xFF46B7E3)
                    : isLast
                    ? const Color(0xFFF4C20D)
                    : theme.colorScheme.onSurface.withOpacity(0.85);
                final weight = isFirst || isLast
                    ? FontWeight.w800
                    : FontWeight.w700;
                return SideTitleWidget(
                  meta: meta,
                  space: 12,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: weight,
                      letterSpacing: 1.0,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.lineBarSpots == null ||
                response.lineBarSpots!.isEmpty) {
              setState(() => _touchedTime = null);
              return;
            }
            final spot = response.lineBarSpots!.first;
            setState(
              () => _touchedTime = start.add(Duration(minutes: spot.x.round())),
            );
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map<LineTooltipItem?>((_) => null)
                .toList(), // hide text tooltip
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 0,
          ),
          getTouchedSpotIndicator: (barData, indexes) {
            return indexes
                .map(
                  (i) => TouchedSpotIndicatorData(
                    FlLine(
                      color: Colors.white.withOpacity(0.6),
                      strokeWidth: 1,
                      dashArray: const [4, 6],
                    ),
                    FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 8,
                            color: Colors.white,
                            strokeWidth: 4,
                            strokeColor: Colors.white.withOpacity(0.18),
                          ),
                    ),
                  ),
                )
                .toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: widget.sleeps.isEmpty,
            curveSmoothness: 0.32,
            color: Colors.white,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                const Color(0xFF76C9F1),
                const Color(0xFF0A1B2C),
              ],
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // No chart background (transparent like other charts)
          // Gradient vertical REM overlays (custom painter with vertical + edge fade)
          Positioned.fill(
            child: CustomPaint(
              painter: _VerticalRemPainter(
                start: start,
                end: end,
                minY: widget.minY,
                maxY: widget.maxY,
                remWindows: widget.remWindows,
                bottomReserved: bottomReserved,
              ),
            ),
          ),
          chart,
          if (_touchedTime != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Text(
                    _fmt(_touchedTime!, withMinutes: true),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(DateTime t, {required bool withMinutes}) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return withMinutes ? '$hh:$mm' : hh;
  }
}

// Convert discrete state change events into a step-like sample series.
// Expects entries sorted by time ascending (we sort defensively in caller).
List<SleepSample> _expandDiscreteToSteps(List<SleepPoint> points) {
  if (points.isEmpty) return const [];
  final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
  final samples = <SleepSample>[];
  // Start with first state
  final first = sorted.first;
  samples.add(SleepSample(time: first.time, level: first.state.toDouble()));
  for (var i = 1; i < sorted.length; i++) {
    final prev = sorted[i - 1];
    final curr = sorted[i];
    // Keep previous level until the change time
    samples.add(SleepSample(time: curr.time, level: prev.state.toDouble()));
    samples.add(SleepSample(time: curr.time, level: curr.state.toDouble()));
  }
  return samples;
}

class _VerticalRemPainter extends CustomPainter {
  _VerticalRemPainter({
    required this.start,
    required this.end,
    required this.minY,
    required this.maxY,
    required this.remWindows,
    required this.bottomReserved,
  });

  final DateTime start;
  final DateTime end;
  final double minY;
  final double maxY;
  final List<TimeRange> remWindows;
  final double bottomReserved;

  @override
  void paint(Canvas canvas, Size size) {
    if (remWindows.isEmpty) return;

    final totalMinutes = end.difference(start).inMinutes.toDouble();
    if (totalMinutes <= 0) return;

    for (final r in remWindows) {
      final rs = r.start.isBefore(start) ? start : r.start;
      final re = r.end.isAfter(end) ? end : r.end;
      if (!re.isAfter(rs)) continue;

      final x1 = ((rs.difference(start).inMinutes.toDouble()) / totalMinutes) * size.width;
      final x2 = ((re.difference(start).inMinutes.toDouble()) / totalMinutes) * size.width;

      // Fill down to the x-axis baseline (exclude bottom titles), fading to transparent at the bottom
      final rect = Rect.fromLTRB(x1, 0, x2, size.height - bottomReserved);
      final verticalShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF047163), // strong teal top
          Color(0xFF078776), // mid teal
          Color(0x007EE6D8), // transparent teal at bottom
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(rect);

      // Use a fade towards edges for subtle spotlight
      final fadeShader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF7EE6D8).withOpacity(0.0),
            const Color(0xFF7EE6D8).withOpacity(0.12),
            const Color(0xFF7EE6D8).withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, Paint()..shader = verticalShader);
      canvas.drawRect(rect, Paint()..shader = fadeShader);
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalRemPainter oldDelegate) {
    return start != oldDelegate.start ||
        end != oldDelegate.end ||
        minY != oldDelegate.minY ||
        maxY != oldDelegate.maxY ||
        remWindows != oldDelegate.remWindows;
  }
}
