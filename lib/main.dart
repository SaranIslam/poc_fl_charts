import 'package:flutter/material.dart';
import 'widgets/weekly_grouped_bar_chart.dart';

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
      home: const ChartDemoPage(),
    );
  }
}

class ChartDemoPage extends StatelessWidget {
  const ChartDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final weeks = [
      WeekGroup(
        label: '14 - 20 ก.ค.',
        selected: false,
        entries: const [
          BarEntry(value: 85),
          BarEntry(value: 72),
          BarEntry(value: 50),
          BarEntry(value: 90),
          BarEntry(value: 80),
          BarEntry(value: 95),
        ],
        average: null, // compute from all bars
        averageColor: Colors.white,
      ),
      WeekGroup(
        label: '21 - 27 ก.ค.',
        selected: true,
        entries: const [
          BarEntry(value: 65),
          BarEntry(value: 63),
          BarEntry(value: 64),
        ],
        average: 70,
        averageColor: Colors.lightBlueAccent,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D10),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Weekly Grouped Bar Chart'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: WeeklyGroupedBarChart(
          weeks: weeks,
          gridInterval: 20,
          groupBarWidth: 14,
          barsSpace: 8,
          groupsSpace: 28,
          barColor: Colors.blueAccent,
          leftTitleFormatter: (v) => v.toStringAsFixed(0),
          bottomTitlesReservedSize: 56,
          bottomTitlesSpace: 16,
        ),
      ),
    );
  }
}
