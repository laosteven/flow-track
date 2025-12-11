import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session_service.dart';
import '../services/stroke_analyzer.dart';
import '../models/sensor_data.dart';

class SessionReviewScreen extends StatefulWidget {
  final File file;
  final SessionService sessionService;

  const SessionReviewScreen({super.key, required this.file, required this.sessionService});

  @override
  State<SessionReviewScreen> createState() => _SessionReviewScreenState();
}

class _SessionReviewScreenState extends State<SessionReviewScreen> {
  Map<String, dynamic>? _data;
  final StrokeAnalyzer _analyzer = StrokeAnalyzer();
  List<double> _magnitudes = [];
  List<int> _strokeIndices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final map = await widget.sessionService.loadSession(widget.file);
    setState(() => _data = map);

    final samples = (map['samples'] as List<dynamic>).map((s) {
      return AccelerometerData(
        x: (s['x'] as num).toDouble(),
        y: (s['y'] as num).toDouble(),
        z: (s['z'] as num).toDouble(),
        timestamp: DateTime.parse(s['t'] as String),
      );
    }).toList();

    // Reset analyzer and re-run it to reconstruct magnitudes and stroke detections using sample timestamps
    _analyzer.reset();
    for (final s in samples) {
      _analyzer.processAccelerometerData(s);
      _magnitudes.add(s.magnitude);
    }

    // If session contains saved stroke timestamps, map them to nearest sample indices
    if (map.containsKey('strokes')) {
      final strokes = map['strokes'] as List<dynamic>;
      for (final st in strokes) {
        final ts = DateTime.parse(st['timestamp'] as String);
        // find nearest sample index by timestamp
        int nearest = 0;
        int bestDiff = 1 << 30;
        for (int i = 0; i < samples.length; i++) {
          final diff = (samples[i].timestamp.difference(ts).inMilliseconds).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            nearest = i;
          }
        }
        _strokeIndices.add(nearest);
      }
    } else {
      // Fallback: mark local peaks
      for (int i = 1; i < _magnitudes.length - 1; i++) {
        if (_magnitudes[i] > _magnitudes[i - 1] && _magnitudes[i] > _magnitudes[i + 1] && _magnitudes[i] > 0.8) {
          _strokeIndices.add(i);
        }
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.file.path.split(Platform.pathSeparator).last;
    final strokeRate = _analyzer.getStrokeRate();
    final consistency = _analyzer.getConsistency();
    final total = _analyzer.getTotalStrokes();
    final avgPower = _analyzer.getAveragePower();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Review: $title'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                final csv = await widget.sessionService.exportSessionCsv(widget.file);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported CSV: $csv')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await widget.sessionService.deleteSession(widget.file);
                Navigator.of(context).pop();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Overview'), Tab(text: 'Graphs')],
          ),
        ),
        body: _data == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Overview tab - 2-column grid
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Average SPM', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(strokeRate.toStringAsFixed(1), style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Consistency', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('${consistency.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Strokes', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(total.toString(), style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Average Power', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(avgPower.toStringAsFixed(2), style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Graphs tab
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Container(
                          height: 220,
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: LineChart(
                            LineChartData(
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(_magnitudes.length, (i) => FlSpot(i.toDouble(), _magnitudes[i])),
                                  isCurved: true,
                                  curveSmoothness: 0.2,
                                  color: Colors.blue,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.withOpacity(0.25), Colors.blue.withOpacity(0.05)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                              extraLinesData: ExtraLinesData(verticalLines: _strokeIndices.map((i) => VerticalLine(x: i.toDouble(), color: Colors.red.withOpacity(0.6), strokeWidth: 1)).toList()),
                              gridData: FlGridData(show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Detected strokes: ${_strokeIndices.length}'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
