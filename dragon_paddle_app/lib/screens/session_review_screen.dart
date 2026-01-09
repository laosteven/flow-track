import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/session_service.dart';
import '../services/session_share_service.dart';
import '../services/stroke_analyzer.dart';
import '../models/sensor_data.dart';
import '../widgets/session_report_widget.dart';

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
  final List<double> _magnitudes = [];
  final List<int> _strokeIndices = [];
  List<double> _strokeMagnitudes = [];
  List<double> _spmSeries = [];
  List<double> _consistencySeries = [];
  List<double> _avgPowerSeries = [];
  List<double> _distanceSeries = [];
  List<double> _speedSeries = [];
  List<double> _split500mSeries = [];
  final ScreenshotController _screenshotController = ScreenshotController();
  String _magnitudeChartType = 'line'; // 'line', 'step'

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
      _distanceSeries = [];
      _speedSeries = [];
      _split500mSeries = [];
      for (final m in metrics) {
        try {
          final spm = (m['spm'] as num?)?.toDouble() ?? 0.0;
          final cons = (m['consistency'] as num?)?.toDouble() ?? 0.0;
          final ap = (m['avgPower'] as num?)?.toDouble() ?? 0.0;
          final dist = (m['distance'] as num?)?.toDouble() ?? 0.0;
          final spd = (m['speed'] as num?)?.toDouble() ?? 0.0;
          final split = (m['split500m'] as num?)?.toDouble() ?? 0.0;
          _spmSeries.add(spm);
          _consistencySeries.add(cons);
          _avgPowerSeries.add(ap);
          _distanceSeries.add(dist);
          _speedSeries.add(spd);
          _split500mSeries.add(split);
        } catch (_) {}
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final distance = _analyzer.getDistance();
    final speed = _analyzer.getSpeed();
    final split500m = _analyzer.getSplit500m();
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
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'share':
                    await _shareSession();
                    break;
                  case 'export':
                    final messenger = ScaffoldMessenger.of(context);
                    final csv = await widget.sessionService.exportSessionCsv(
                      widget.file,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Exported CSV: $csv')),
                      );
                    }
                    break;
                  case 'report':
                    await _generateReport();
                    break;
                  case 'rename':
                    await _renameSession();
                    break;
                  case 'delete':
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete session?'),
                        content: const Text(
                          'Are you sure you want to delete this session?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await widget.sessionService.deleteSession(widget.file);
                      if (mounted) {
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pop();
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 12),
                      Text('Rename'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share),
                      SizedBox(width: 12),
                      Text('Share'),
                    ],
                  ),
                ),
                // const PopupMenuItem(
                //   value: 'export',
                //   child: Row(
                //     children: [
                //       Icon(Icons.download),
                //       SizedBox(width: 12),
                //       Text('Export CSV'),
                //     ],
                //   ),
                // ),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.description),
                      SizedBox(width: 12),
                      Text('Generate report'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
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
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
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
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
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
                                  'Total strokes',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  total.toString(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
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
                                  'Average power',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  avgPower.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
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
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Distance',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${distance.toStringAsFixed(0)} m',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Spacer(),
                                SizedBox(
                                  height: 40,
                                  child: _miniChart(
                                    _distanceSeries.isNotEmpty
                                        ? _distanceSeries
                                        : _magnitudes,
                                    color: Colors.green,
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
                                  'Speed',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${speed.toStringAsFixed(2)} m/s',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Spacer(),
                                SizedBox(
                                  height: 40,
                                  child: _miniChart(
                                    _speedSeries.isNotEmpty
                                        ? _speedSeries
                                        : _magnitudes,
                                    color: Colors.purple,
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
                                  'Split (500m)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  split500m > 0
                                      ? '${split500m.floor()}:${((split500m % 1) * 60).round().toString().padLeft(2, '0')}'
                                      : '—',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Spacer(),
                                SizedBox(
                                  height: 40,
                                  child: _miniChart(
                                    _split500mSeries.isNotEmpty
                                        ? _split500mSeries
                                        : _magnitudes,
                                    color: Colors.red,
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
            color: color.withValues(alpha: 0.9),
            barWidth: 1.4,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.04),
                ],
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
    final isMagnitude = title == 'Magnitude';
    final chartType = isMagnitude ? _magnitudeChartType : 'line';

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
                if (isMagnitude) ...[
                  PopupMenuButton<String>(
                    initialValue: _magnitudeChartType,
                    onSelected: (value) {
                      setState(() => _magnitudeChartType = value);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'line',
                        child: Text('Line chart'),
                      ),
                      const PopupMenuItem(
                        value: 'step',
                        child: Text('Step chart'),
                      ),
                    ],
                    child: const Icon(Icons.bar_chart, size: 20),
                  ),
                ],
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
                  : _buildChart(values, color, chartType),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<double> values, Color color, String chartType) {
    // Downsample data for smoother visualization (use every 5th point)
    final downsampledValues = _downsampleData(values, 5);

    switch (chartType) {
      case 'step':
        return _buildStepChart(downsampledValues, color);
      case 'line':
      default:
        return _buildLineChart(downsampledValues, color);
    }
  }

  List<double> _downsampleData(List<double> data, int factor) {
    if (data.length <= factor * 2) return data;
    final result = <double>[];
    for (int i = 0; i < data.length; i += factor) {
      result.add(data[i]);
    }
    return result;
  }

  Widget _buildLineChart(List<double> values, Color color) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find max and min indices
    int maxIndex = 0;
    int minIndex = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[maxIndex]) maxIndex = i;
      if (values[i] < values[minIndex]) minIndex = i;
    }

    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              values.length,
              (i) => FlSpot(i.toDouble(), values[i]),
            ),
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                // Only show dots for max and min points
                return spot.x == maxIndex.toDouble() ||
                    spot.x == minIndex.toDouble();
              },
              getDotPainter: (spot, percent, barData, index) {
                final isMax = spot.x == maxIndex.toDouble();
                return FlDotCirclePainter(
                  radius: 4,
                  color: isMax ? Colors.green : Colors.red,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildStepChart(List<double> values, Color color) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find max and min indices
    int maxIndex = 0;
    int minIndex = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[maxIndex]) maxIndex = i;
      if (values[i] < values[minIndex]) minIndex = i;
    }

    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              values.length,
              (i) => FlSpot(i.toDouble(), values[i]),
            ),
            isCurved: false,
            isStepLineChart: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                // Only show dots for max and min points
                return spot.x == maxIndex.toDouble() ||
                    spot.x == minIndex.toDouble();
              },
              getDotPainter: (spot, percent, barData, index) {
                final isMax = spot.x == maxIndex.toDouble();
                return FlDotCirclePainter(
                  radius: 4,
                  color: isMax ? Colors.green : Colors.red,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
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
                                    color.withValues(alpha: 0.25),
                                    color.withValues(alpha: 0.05),
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

  Future<void> _shareSession() async {
    try {
      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing session for sharing...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Export the session data - just save as JSON file
      final sessionName = _data?['name'] as String? ?? 'Session';
      final paddlerName = _data?['paddlerName'] as String? ?? '';

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final safeName = sessionName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final safePaddlerName = paddlerName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Avoid duplicate paddler name in filename
      // If session name already starts with paddler name, don't prepend it
      final bool nameStartsWithPaddler =
          safePaddlerName.isNotEmpty &&
          safeName.toLowerCase().startsWith(safePaddlerName.toLowerCase());

      final fileName = safePaddlerName.isNotEmpty && !nameStartsWithPaddler
          ? '${safePaddlerName}_${safeName}_$timestamp.flowtrack'
          : '${safeName}_$timestamp.flowtrack';
      final jsonFile = File('${tempDir.path}/$fileName');
      await jsonFile.writeAsString(json.encode(_data));

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Share the JSON file directly
      final displayName = paddlerName.isNotEmpty ? paddlerName : sessionName;
      final message =
          '🐉 Flow Track Session: $displayName\n\n'
          '📎 Download and open the attached file in Flow Track app.\n\n'
          'Tip: Tap the file after downloading to import automatically!';

      await Share.shareXFiles(
        [XFile(jsonFile.path)],
        text: message,
        subject: 'Flow Track session: $displayName',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session shared successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share session: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _renameSession() async {
    final paddlerName = _data?['paddlerName'] as String? ?? '';
    final paddlerController = TextEditingController(text: paddlerName);

    // Extract current filename without path and extension
    String currentFilename = widget.file.path
        .split(Platform.pathSeparator)
        .last;
    currentFilename = currentFilename
        .replaceAll('.json', '')
        .replaceAll('.flowtrack', '');
    final filenameController = TextEditingController(text: currentFilename);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: filenameController,
              decoration: const InputDecoration(
                labelText: 'Filename (without extension)',
                hintText: 'Enter filename',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paddlerController,
              decoration: const InputDecoration(
                labelText: 'Paddler name',
                hintText: 'Enter paddler name',
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop({
              'paddlerName': paddlerController.text.trim(),
              'filename': filenameController.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newPaddlerName = result['paddlerName'] ?? '';
      final newFilename = result['filename'] ?? '';

      bool updated = false;

      // Update paddler name if changed
      if (newPaddlerName.isNotEmpty && newPaddlerName != paddlerName) {
        _data?['paddlerName'] = newPaddlerName;
        await widget.sessionService.updatePaddlerName(
          widget.file,
          newPaddlerName,
        );
        updated = true;
      }

      // Rename file if changed
      if (newFilename.isNotEmpty && newFilename != currentFilename) {
        final directory = widget.file.parent;
        // Preserve the original extension
        final extension = widget.file.path.endsWith('.flowtrack')
            ? '.flowtrack'
            : '.json';
        final newPath =
            '${directory.path}${Platform.pathSeparator}$newFilename$extension';
        final newFile = File(newPath);

        // Check if new filename already exists
        if (await newFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A file with that name already exists'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          try {
            await widget.file.rename(newPath);
            updated = true;

            // Update the widget's file reference by replacing current screen
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => SessionReviewScreen(
                    file: newFile,
                    sessionService: widget.sessionService,
                  ),
                ),
              );
            }
            return;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to rename file: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }

      if (updated) {
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session renamed successfully')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    // Pop with true to signal list should refresh if any changes were made
    super.dispose();
  }

  Future<void> _generateReport() async {
    try {
      final title = widget.file.path.split(Platform.pathSeparator).last;
      final paddlerName = _data?['paddlerName'] as String? ?? '';
      final strokeRate = _analyzer.getStrokeRate();
      final consistency = _analyzer.getConsistency();
      final total = _analyzer.getTotalStrokes();
      final avgPower = _analyzer.getAveragePower();
      final distance = _analyzer.getDistance();
      final speed = _analyzer.getSpeed();
      final split500m = _analyzer.getSplit500m();

      // Parse filename to extract date/time (format: 2025-12-21_01-58-40.json or .flowtrack)
      String formattedDate = title;
      try {
        String nameWithoutExt = title
            .replaceAll('.json', '')
            .replaceAll('.flowtrack', '');
        final parts = nameWithoutExt.split('_');
        if (parts.length == 2) {
          final dateParts = parts[0].split('-');
          final timeParts = parts[1].split('-');
          if (dateParts.length == 3 && timeParts.length == 3) {
            final dateTime = DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
              int.parse(timeParts[2]),
            );
            // Format as: December 21, 2025 at 1:58 AM
            final months = [
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December',
            ];
            final hour = dateTime.hour;
            final minute = dateTime.minute.toString().padLeft(2, '0');
            final amPm = hour >= 12 ? 'PM' : 'AM';
            final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
            formattedDate =
                '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $hour12:$minute $amPm';
          }
        }
      } catch (_) {
        // If parsing fails, use original filename
      }

      // Navigate to report screen where we can capture it properly
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ReportCaptureScreen(
              screenshotController: _screenshotController,
              sessionName: formattedDate,
              paddlerName: paddlerName,
              strokeRate: strokeRate,
              consistency: consistency,
              totalStrokes: total,
              avgPower: avgPower,
              distance: distance,
              speed: speed,
              split500m: split500m,
              magnitudes: _magnitudes,
              spmSeries: _spmSeries,
              consistencySeries: _consistencySeries,
              avgPowerSeries: _avgPowerSeries,
              distanceSeries: _distanceSeries,
              speedSeries: _speedSeries,
              split500mSeries: _split500mSeries,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating report: $e')));
      }
    }
  }
}

// Helper screen to render and capture the report
class _ReportCaptureScreen extends StatefulWidget {
  final ScreenshotController screenshotController;
  final String sessionName;
  final String paddlerName;
  final double strokeRate;
  final double consistency;
  final int totalStrokes;
  final double avgPower;
  final double distance;
  final double speed;
  final double split500m;
  final List<double> magnitudes;
  final List<double> spmSeries;
  final List<double> consistencySeries;
  final List<double> avgPowerSeries;
  final List<double> distanceSeries;
  final List<double> speedSeries;
  final List<double> split500mSeries;

  const _ReportCaptureScreen({
    required this.screenshotController,
    required this.sessionName,
    required this.paddlerName,
    required this.strokeRate,
    required this.consistency,
    required this.totalStrokes,
    required this.avgPower,
    required this.distance,
    required this.speed,
    required this.split500m,
    required this.magnitudes,
    required this.spmSeries,
    required this.consistencySeries,
    required this.avgPowerSeries,
    required this.distanceSeries,
    required this.speedSeries,
    required this.split500mSeries,
  });

  @override
  State<_ReportCaptureScreen> createState() => _ReportCaptureScreenState();
}

class _ReportCaptureScreenState extends State<_ReportCaptureScreen> {
  bool _showCloseButton = false;
  bool _isCapturing = true;

  @override
  void initState() {
    super.initState();
    // Capture after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureAndShare();
    });
  }

  Future<void> _captureAndShare() async {
    try {
      // Wait a bit for rendering to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Capture the screenshot
      final image = await widget.screenshotController.capture();
      if (image == null) {
        throw Exception('Failed to capture screenshot');
      }

      setState(() {
        _isCapturing = false;
      });

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(image);

      // Share the image
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Session Report - ${widget.paddlerName}',
        text: 'Session report for ${widget.sessionName}',
      );

      // Show close button after a short delay
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _showCloseButton = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _showCloseButton = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Screenshot(
            controller: widget.screenshotController,
            child: SessionReportWidget(
              sessionName: widget.sessionName,
              paddlerName: widget.paddlerName,
              strokeRate: widget.strokeRate,
              consistency: widget.consistency,
              totalStrokes: widget.totalStrokes,
              avgPower: widget.avgPower,
              distance: widget.distance,
              speed: widget.speed,
              split500m: widget.split500m,
              magnitudes: widget.magnitudes,
              spmSeries: widget.spmSeries,
              consistencySeries: widget.consistencySeries,
              avgPowerSeries: widget.avgPowerSeries,
              distanceSeries: widget.distanceSeries,
              speedSeries: widget.speedSeries,
              split500mSeries: widget.split500mSeries,
            ),
          ),
          // Loading indicator
          if (_isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Generating report...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Close button
          if (_showCloseButton)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
