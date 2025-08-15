import 'package:flutter/material.dart';
import 'widgets/weekly_grouped_bar_chart.dart';
import 'widgets/simple_weekly_bar_chart.dart';
import 'widgets/simple_weekly_line_chart.dart';
import 'widgets/sleep_cycle_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fl Chart POC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ChartsHomePage(),
    );
  }
}

class ChartsHomePage extends StatelessWidget {
  const ChartsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Weekly grouped data (2 groups)
    final weeks = [
      WeekGroup(
        label: '14 - 20 ก.ค.',
        selected: false,
        entries: const [
          BarEntry(value: 50),
          BarEntry(value: 80),
          BarEntry(value: 30),
          BarEntry(value: 70),
          BarEntry(value: 60),
          BarEntry(value: 60),
          BarEntry(value: 70),
        ],
        average: null,
        averageColor: Colors.white,
      ),
      WeekGroup(
        label: '21 - 27 ก.ค.',
        selected: true,
        entries: const [
          BarEntry(value: 90),
          BarEntry(value: 50),
          BarEntry(value: 70),
        ],
        // average: 70,
        averageColor: Colors.lightBlueAccent,
      ),
    ];

    // Simple weekly 7-day data
    final simpleDays = const [
      DayValue(dayShort: 'จ', dateLabel: '10', value: 3),
      DayValue(dayShort: 'อ', dateLabel: '11', value: 4),
      DayValue(dayShort: 'พ', dateLabel: '12', value: 2),
      DayValue(dayShort: 'พฤ', dateLabel: '13', value: 5),
      DayValue(dayShort: 'ศ', dateLabel: '14', value: 6),
      DayValue(dayShort: 'ส', dateLabel: '15', value: 3),
      DayValue(dayShort: 'อา', dateLabel: '16', value: 4),
    ];

    // Sleep-cycle data in your desired raw format → mapped to chart inputs
    DateTime parseHms(String hms, DateTime anchor, DateTime prev) {
      final p = hms.split(':').map(int.parse).toList();
      var dt = DateTime(anchor.year, anchor.month, anchor.day, p[0], p[1], p[2]);
      if (dt.isBefore(prev)) dt = dt.add(const Duration(days: 1)); // cross midnight
      return dt;
    }

    final anchor = DateTime(2024, 1, 1, 21, 30);

    // Raw discrete states (0..2) with HH:mm:ss
    final rawSleeps = [
      {'state': 2, 'time': '23:10:00'}, // awake
      {'state': 1, 'time': '23:30:00'},
      {'state': 0, 'time': '00:20:00'},
      {'state': 1, 'time': '01:10:00'},
      {'state': 0, 'time': '01:40:00'},
      {'state': 1, 'time': '02:30:00'},
      {'state': 2, 'time': '03:10:00'},
      {'state': 1, 'time': '03:20:00'},
      {'state': 0, 'time': '03:50:00'},
      {'state': 1, 'time': '04:30:00'},
      {'state': 2, 'time': '05:50:00'},
      {'state': 1, 'time': '06:00:00'},
      {'state': 2, 'time': '06:40:00'},
    ];

    // Raw REM windows
    final rawRems = [
      {'start': '02:30:00', 'end': '03:50:00'},
      {'start': '05:30:00', 'end': '06:00:00'},
    ];

    // Map to chart models: discrete sleeps + REMs
    final sleeps = <SleepPoint>[];
    var prev = anchor;
    for (final s in rawSleeps) {
      final dt = parseHms(s['time'] as String, anchor, prev);
      sleeps.add(SleepPoint(state: s['state'] as int, time: dt));
      prev = dt;
    }

    final rems = <TimeRange>[];
    prev = anchor;
    for (final r in rawRems) {
      final rs = parseHms(r['start'] as String, anchor, prev);
      final re = parseHms(r['end'] as String, anchor, rs);
      rems.add(TimeRange(start: rs, end: re));
      prev = re;
    }

    // Build fine-grained samples (curved line) from discrete sleeps
    double levelFor(int s) => s == 0 ? 0.2 : (s == 1 ? 1.1 : 1.9);
    final samples = <SleepSample>[];
    if (sleeps.isNotEmpty) {
      for (var i = 0; i < sleeps.length; i++) {
        final cur = sleeps[i];
        final curLevel = levelFor(cur.state);
        if (i == 0) {
          samples.add(SleepSample(time: cur.time, level: curLevel));
          continue;
        }
        final prevPt = sleeps[i - 1];
        final prevLevel = levelFor(prevPt.state);
        final mid = prevPt.time.add(
          Duration(milliseconds: (cur.time.difference(prevPt.time).inMilliseconds * 0.6).round()),
        );
        // Start at previous level, move towards mid average, then reach new level
        samples.add(SleepSample(time: mid, level: (prevLevel + curLevel) / 2));
        samples.add(SleepSample(time: cur.time, level: curLevel));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D10),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Charts Showcase'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Weekly Grouped
          Text(
            'Weekly Grouped Bar Chart',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: WeeklyGroupedBarChart(
              weeks: weeks,
              gridInterval: 20,
              groupsSpace: 28,
              barColor: Colors.blueAccent,
              leftTitleFormatter: (v) => v.toStringAsFixed(0),
              bottomTitlesReservedSize: 56,
              bottomTitlesSpace: 16,
            ),
          ),
          const SizedBox(height: 32),

          // Simple Weekly Bar
          Text(
            'Simple Weekly Bar Chart',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: SimpleWeeklyBarChart(
              days: simpleDays,
              minY: 0,
              gridInterval: 1,
              barWidth: 18,
              groupsSpace: 18,
              bottomTitlesReservedSize: 44,
            ),
          ),
          const SizedBox(height: 32),

          // Simple Weekly Line
          Text(
            'Simple Weekly Line Chart',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: SimpleWeeklyLineChart(
              days: simpleDays,
              minY: 0,
              gridInterval: 1,
              leftTitlesReservedSize: 40,
              bottomTitlesReservedSize: 44,
              avgY: 4.0,
            ),
          ),
          const SizedBox(height: 32),

          // Sleep Cycle Chart
          Text(
            'Sleep Cycle Chart',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          // Put the chart inside a RepaintBoundary to reduce parent layout invalidations
          RepaintBoundary(
            child: SizedBox(
              height: 300,
              child: SleepCycleChart(
                samples: samples,
                sleeps: const [], // using samples for curved line
                remWindows: rems,
                highlightTime: samples.isNotEmpty ? samples[(samples.length * 0.6).floor()].time : null,
                minY: 0,
                maxY: 2,
                bottomTitlesReserved: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
