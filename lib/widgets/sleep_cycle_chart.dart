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
    this.highlightTime,
    this.minY = 0,
    this.maxY = 2,
    this.bottomTitlesReserved = 56,
  });

  final List<SleepSample> samples; // optional numeric
  final List<SleepPoint> sleeps; // discrete states
  final List<TimeRange> remWindows;
  final DateTime? highlightTime;
  final double minY;
  final double maxY;
  final double bottomTitlesReserved;

  @override
  State<SleepCycleChart> createState() => _SleepCycleChartState();
}

class _SleepCycleChartState extends State<SleepCycleChart> {
  DateTime? _touchedTime; // tracks the last touched time for the centered badge
  @override
  Widget build(BuildContext context) {
    // choose source
    final samples = widget.sleeps.isNotEmpty
        ? _expandDiscreteToSteps(widget.sleeps)
        : widget.samples;
    if (samples.isEmpty) return const SizedBox.shrink();

    // keep theme handy for internal colors if needed later
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

    // Build x-axis allowed tick minutes with density adaptive to width
    final lastMinuteInt = end.difference(start).inMinutes;
    final allowedTicks = <int>{};
    final width = MediaQuery.of(context).size.width;
    // Estimate capacity with tighter spacing so large screens can show each hour
    // Note: we no longer rely on max label count; labels are generated every hour
    // and edge-adjacent hours can be suppressed on compact screens.
    // Always try 1h interval; we will optionally skip the edge-adjacent hours on very small screens
    const int stepHours = 1;

    // First full clock-hour strictly after start (align to HH:00)
    DateTime nextTick = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour + 1,
    );
    // Generate interior hour ticks aligned to the clock
    for (
      var t = nextTick;
      t.isBefore(end);
      t = t.add(const Duration(hours: stepHours))
    ) {
      final mins = t.difference(start).inMinutes;
      allowedTicks.add(mins);
    }

    // On small screens, hide the first and last interior hour if the start/end carry minutes,
    // to avoid crowding against the hh:mm edge labels (e.g., 23:10 vs 00, 05 vs 05:30)
    final bool compact = width < 420; // adjust if needed
    if (compact && allowedTicks.isNotEmpty) {
      if (start.minute != 0) {
        final firstInterior = nextTick.difference(start).inMinutes;
        allowedTicks.remove(firstInterior);
      }
      if (end.minute != 0) {
        final lastHourBeforeEnd = DateTime(
          end.year,
          end.month,
          end.day,
          end.hour,
        );
        final lastInterior = lastHourBeforeEnd.difference(start).inMinutes;
        allowedTicks.remove(lastInterior);
      }
    }

    final double bottomReserved = widget.bottomTitlesReserved; // matches chart titles reserved space

    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: lastMinuteInt.toDouble(),
        minY: widget.minY,
        maxY: widget.maxY,
        showingTooltipIndicators: showing,
        gridData: const FlGridData(show: false),
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
              interval: 1, // minutes; we'll filter to exact hour ticks
              getTitlesWidget: (value, meta) {
                final minute = value.round();
                const epsilon = 1; // 1 minute tolerance
                final isStart = (minute - 0).abs() <= epsilon;
                final isEnd = (minute - lastMinuteInt).abs() <= epsilon;

                TextStyle base = TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                );

                Widget make(String text, {Color? color, FontWeight? weight}) {
                  final label = Text(
                    text,
                    style: base.copyWith(
                      color: color ?? base.color,
                      fontWeight: weight ?? base.fontWeight,
                    ),
                  );
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    // keep labels fully inside chart bounds
                    fitInside: SideTitleFitInsideData.fromTitleMeta(
                      meta,
                      distanceFromEdge: 2,
                    ),
                    child: label,
                  );
                }

                if (isStart) {
                  return make(
                    _fmt(start, withMinutes: true),
                    color: const Color(0xFF46B7E3),
                    weight: FontWeight.w800,
                  );
                }
                if (isEnd) {
                  return make(
                    _fmt(end, withMinutes: true),
                    color: const Color(0xFFF4C20D),
                    weight: FontWeight.w800,
                  );
                }
                if (!allowedTicks.contains(minute)) {
                  return const SizedBox.shrink();
                }
                final dt = start.add(Duration(minutes: minute));
                return make(_fmt(dt, withMinutes: false));
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
            final dt = start.add(Duration(minutes: spot.x.round()));
            setState(() => _touchedTime = dt);
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) =>
                spots.map<LineTooltipItem?>((_) => null).toList(),
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
                      dashArray: [4, 6],
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
                const Color(0xFFEBEDEF),
                const Color(0xFFA7D7F0),
                const Color(0xFF2E3B8B),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Fixed-height top area for the centered badge to avoid ListView relayout during touch
        SizedBox(
          height: 80,
          child: Center(
            child: IgnorePointer(
              child: Opacity(
                opacity: _touchedTime != null ? 1.0 : 0.0,
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
                    _touchedTime != null
                        ? 'LEVEL ${_fmt(_touchedTime!, withMinutes: true)}'
                        : 'LEVEL 00:00',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Vertical REM overlays
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
                // Line halo glow (under the chart so indicators stay visible)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LineGlowPainter(
                      spots: spots,
                      minY: widget.minY,
                      maxY: widget.maxY,
                      start: start,
                      end: end,
                      remWindows: widget.remWindows,
                      bottomReserved: bottomReserved,
                    ),
                  ),
                ),
                // Chart with built-in bottom titles (drawn last so touch indicator is on top)
                chart,
              ],
            ),
          ),
        ),
      ],
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

      final x1 =
          ((rs.difference(start).inMinutes.toDouble()) / totalMinutes) *
          size.width;
      final x2 =
          ((re.difference(start).inMinutes.toDouble()) / totalMinutes) *
          size.width;

      // Fill down to the x-axis baseline (exclude bottom titles), fading to transparent at the bottom
      final rect = Rect.fromLTRB(x1, 0, x2, size.height - bottomReserved);
      final verticalShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(94, 182, 169, 0.24),
          Color.fromRGBO(94, 182, 169, 0.02),
        ],
        stops: [0.0, 0.6804],
      ).createShader(rect);

      canvas.drawRect(rect, Paint()..shader = verticalShader);

      // Solid base bar at the bottom of each REM window (height = 6px)
      final double baselineY = size.height - bottomReserved;
      final double barTopY = (baselineY - 6).clamp(0.0, baselineY);
      final Rect baseBar = Rect.fromLTRB(x1, barTopY, x2, baselineY);
      final Paint basePaint = Paint()..color = const Color(0xFF5EB6A9);
      canvas.drawRect(baseBar, basePaint);

      // Note: precise line-halo glow requires sampling the polyline; keeping band-only visuals here.
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

class _LineGlowPainter extends CustomPainter {
  _LineGlowPainter({
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.start,
    required this.end,
    required this.remWindows,
    required this.bottomReserved,
  });

  final List<FlSpot> spots;
  final double minY;
  final double maxY;
  final DateTime start;
  final DateTime end;
  final List<TimeRange> remWindows;
  final double bottomReserved;

  @override
  void paint(Canvas canvas, Size size) {
    if (spots.isEmpty || remWindows.isEmpty) return;
    final totalMinutes = end.difference(start).inMinutes.toDouble();
    if (totalMinutes <= 0) return;

    // Helpers to convert data to canvas space
    double xToPx(double minute) => (minute / totalMinutes) * size.width;
    double yToPx(double y) {
      final t = ((y - minY) / (maxY - minY)).clamp(0.0, 1.0);
      // y= maxY → top (0), y=minY → bottom minus titles
      return (1 - t) * (size.height - bottomReserved);
    }

    // Build full path
    final Path fullPath = Path();
    bool first = true;
    for (final sp in spots) {
      final px = xToPx(sp.x);
      final py = yToPx(sp.y);
      if (first) {
        fullPath.moveTo(px, py);
        first = false;
      } else {
        fullPath.lineTo(px, py);
      }
    }

    // For each REM window, clip and draw a soft upward glow only ABOVE the curve
    for (final r in remWindows) {
      final rs = r.start.isBefore(start) ? start : r.start;
      final re = r.end.isAfter(end) ? end : r.end;
      if (!re.isAfter(rs)) continue;
      final x1 = xToPx(rs.difference(start).inMinutes.toDouble());
      final x2 = xToPx(re.difference(start).inMinutes.toDouble());
      final double top = 0;
      final double bottom = size.height - bottomReserved;

      // Build segment points strictly within [x1,x2], including intersections at edges
      final List<Offset> seg = [];
      Offset? prev;
      for (final sp in spots) {
        final pt = Offset(xToPx(sp.x), yToPx(sp.y));
        if (prev == null) {
          prev = pt;
          continue;
        }
        final inPrev = prev.dx >= x1 && prev.dx <= x2;
        final inCurr = pt.dx >= x1 && pt.dx <= x2;
        // If segment crosses x1
        if ((prev.dx < x1 && pt.dx > x1) || (prev.dx > x1 && pt.dx < x1)) {
          final dx = pt.dx - prev.dx;
          if (dx.abs() > 0.0001) {
            final t = (x1 - prev.dx) / dx;
            final y = prev.dy + (pt.dy - prev.dy) * t;
            seg.add(Offset(x1, y));
          }
        }
        // Add current if inside
        if (inCurr) {
          if (seg.isEmpty && inPrev) seg.add(prev); // ensure start
          seg.add(pt);
        }
        // If segment crosses x2
        if ((prev.dx < x2 && pt.dx > x2) || (prev.dx > x2 && pt.dx < x2)) {
          final dx = pt.dx - prev.dx;
          if (dx.abs() > 0.0001) {
            final t = (x2 - prev.dx) / dx;
            final y = prev.dy + (pt.dy - prev.dy) * t;
            seg.add(Offset(x2, y));
          }
        }
        prev = pt;
      }
      if (seg.length < 2) continue;

      // Path along the segment
      final Path segPath = Path()..moveTo(seg.first.dx, seg.first.dy);
      for (int i = 1; i < seg.length; i++) {
        segPath.lineTo(seg[i].dx, seg[i].dy);
      }

      // Clip only to the band, expanded slightly to avoid hard cut of blur
      const double glowPad = 12; // px
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(x1 - glowPad, top - glowPad, x2 + glowPad, bottom + glowPad));

      // Draw a red halo stroke; blur + upward bias
      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color.fromARGB(255, 58, 236, 227)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawPath(segPath, glowPaint);
      // Outer soft halo
      final Paint outer = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color.fromARGB(120, 3, 238, 247)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(segPath, outer);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LineGlowPainter oldDelegate) {
    return spots != oldDelegate.spots ||
        minY != oldDelegate.minY ||
        maxY != oldDelegate.maxY ||
        start != oldDelegate.start ||
        end != oldDelegate.end ||
        remWindows != oldDelegate.remWindows ||
        bottomReserved != oldDelegate.bottomReserved;
  }
}

// _RemGlowOverlay was used in a previous iteration and has been removed to avoid blurring the whole band.
