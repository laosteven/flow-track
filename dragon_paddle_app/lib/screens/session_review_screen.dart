import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session_service.dart';
import '../services/stroke_analyzer.dart';
import '../models/sensor_data.dart';

class SessionReviewScreen extends StatefulWidget {
  final File file;
  final SessionService sessionService;

  const SessionReviewScreen({
    super.key,
    required this.file,
    required this.sessionService,
  });

  @override
  State<SessionReviewScreen> createState() => _SessionReviewScreenState();
}

class _SessionReviewScreenState extends State<SessionReviewScreen> {
  Map<String, dynamic>? _data;
  final StrokeAnalyzer _analyzer = StrokeAnalyzer();
  List<double> _magnitudes = [];
  List<int> _strokeIndices = [];
  List<double> _strokeMagnitudes = [];
  List<double> _spmSeries = [];
  List<double> _consistencySeries = [];
  List<double> _avgPowerSeries = [];

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
      final List<DateTime> strokeTimes = [];
      for (final st in strokes) {
        final ts = DateTime.parse(st['timestamp'] as String);
        strokeTimes.add(ts);
        // find nearest sample index by timestamp
        int nearest = 0;
        int bestDiff = 1 << 30;
        for (int i = 0; i < samples.length; i++) {
          final diff = (samples[i].timestamp.difference(ts).inMilliseconds)
              .abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            nearest = i;
          }
        }
        _strokeIndices.add(nearest);
      }
      // compute stroke magnitudes
      _strokeMagnitudes = _strokeIndices.map((i) => _magnitudes[i]).toList();
      // compute SPM series from strokeTimes (intervals)
      _spmSeries = [];
      for (int i = 1; i < strokeTimes.length; i++) {
        final dt =
            strokeTimes[i].difference(strokeTimes[i - 1]).inMilliseconds /
            1000.0;
        if (dt > 0) {
          _spmSeries.add(60.0 / dt);
        }
      }
    } else {
      // Fallback: mark local peaks
      for (int i = 1; i < _magnitudes.length - 1; i++) {
        if (_magnitudes[i] > _magnitudes[i - 1] &&
            _magnitudes[i] > _magnitudes[i + 1] &&
            _magnitudes[i] > 0.8) {
          _strokeIndices.add(i);
        }
      }
      _strokeMagnitudes = _strokeIndices.map((i) => _magnitudes[i]).toList();
      _spmSeries = [];
    }

    // If session contains saved periodic metrics, prefer those for sparklines
    if (map.containsKey('metrics')) {
      final metrics = map['metrics'] as List<dynamic>;
      _spmSeries = [];
      _consistencySeries = [];
      _avgPowerSeries = [];
      for (final m in metrics) {
        try {
          final spm = (m['spm'] as num).toDouble();
          final cons = (m['consistency'] as num).toDouble();
          final ap = (m['avgPower'] as num).toDouble();
          _spmSeries.add(spm);
          _consistencySeries.add(cons);
          _avgPowerSeries.add(ap);
        } catch (_) {}
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.file.path.split(Platform.pathSeparator).last;
    final paddlerName = _data?['paddlerName'] as String? ?? '';
    final displayTitle = paddlerName.isNotEmpty
        ? '$paddlerName - $title'
        : title;
    final strokeRate = _analyzer.getStrokeRate();
    final consistency = _analyzer.getConsistency();
    final total = _analyzer.getTotalStrokes();
    final avgPower = _analyzer.getAveragePower();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Review: $displayTitle'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                final csv = await widget.sessionService.exportSessionCsv(
                  widget.file,
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Exported CSV: $csv')));
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
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Graphs'),
            ],
          ),
        ),
        body: _data == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                physics: const NeverScrollableScrollPhysics(),
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
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Average SPM',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  strokeRate.toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                const Spacer(),
                                SizedBox(
                                  height: 40,
                                  child: _miniChart(
                                    _spmSeries.isNotEmpty
                                        ? _spmSeries
                                        : _magnitudes,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Consistency',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${consistency.toStringAsFixed(1)}%',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                const Spacer(),
                                SizedBox(
                                  height: 40,
                                  child: _miniChart(
                                    _consistencySeries.isNotEmpty
                                        ? _consistencySeries
                                        : (_strokeMagnitudes.isNotEmpty
                                              ? _strokeMagnitudes
                                              : _magnitudes),
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Strokes',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  total.toString(),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                const Spacer(),
                                SizedBox(
                                  height: 40,
                                  child: _miniChart(
                                    _strokeMagnitudes.isNotEmpty
                                        ? _strokeMagnitudes
                                        : _magnitudes,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Average Power',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  avgPower.toStringAsFixed(2),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                const Spacer(),
                                SizedBox(
                                  height: 40,
                                  child: _miniChart(
                                    _avgPowerSeries.isNotEmpty
                                        ? _avgPowerSeries
                                        : _magnitudes,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Graphs tab: stacked interactive charts
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _chartCard(
                            'Magnitude',
                            _magnitudes,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          _chartCard(
                            'SPM',
                            _spmSeries,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(height: 12),
                          _chartCard(
                            'Consistency',
                            _consistencySeries,
                            color: Colors.teal,
                          ),
                          const SizedBox(height: 12),
                          _chartCard(
                            'Average Power',
                            _avgPowerSeries,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _miniChart(List<double> values, {Color color = Colors.blue}) {
    if (values.isEmpty) return const SizedBox.shrink();
    final spots = List<FlSpot>.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color.withOpacity(0.9),
            barWidth: 1.4,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.18), color.withOpacity(0.04)],
              ),
            ),
          ),
        ],
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _chartCard(
    String title,
    List<double> values, {
    Color color = Colors.blue,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_full),
                  onPressed: () => _openFullscreenChart(title, values, color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: values.isEmpty
                  ? Center(
                      child: Text(
                        'No data',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        lineTouchData: const LineTouchData(enabled: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              values.length,
                              (i) => FlSpot(i.toDouble(), values[i]),
                            ),
                            isCurved: true,
                            curveSmoothness: 0.2,
                            color: color,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  color.withOpacity(0.25),
                                  color.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ],
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreenChart(String title, List<double> values, Color color) {
    // Force landscape for fullscreen chart, add padding so the bottom isn't cut off
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36.0,
                  vertical: 24.0,
                ),
                child: values.isEmpty
                    ? Center(
                        child: Text(
                          'No data',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          lineTouchData: const LineTouchData(enabled: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                values.length,
                                (i) => FlSpot(i.toDouble(), values[i]),
                              ),
                              isCurved: true,
                              curveSmoothness: 0.2,
                              color: color,
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    color.withOpacity(0.25),
                                    color.withOpacity(0.05),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
              ),
            ),
          ),
        )
        .then((_) async {
          // restore portrait orientations
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        });
  }
}
