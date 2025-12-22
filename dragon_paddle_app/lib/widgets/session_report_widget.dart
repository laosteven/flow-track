import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A widget that displays a comprehensive session report
/// This widget is designed to be captured as an image
class SessionReportWidget extends StatelessWidget {
  final String sessionName;
  final String paddlerName;
  final double strokeRate;
  final double consistency;
  final int totalStrokes;
  final double avgPower;
  final List<double> magnitudes;
  final List<double> spmSeries;
  final List<double> consistencySeries;
  final List<double> avgPowerSeries;

  const SessionReportWidget({
    super.key,
    required this.sessionName,
    required this.paddlerName,
    required this.strokeRate,
    required this.consistency,
    required this.totalStrokes,
    required this.avgPower,
    required this.magnitudes,
    required this.spmSeries,
    required this.consistencySeries,
    required this.avgPowerSeries,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1920,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (paddlerName.isNotEmpty) ...[
              Text(
                paddlerName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              sessionName,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 16),

            // Stats Grid
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Average SPM',
                            strokeRate.toStringAsFixed(1),
                            _buildMiniChart(
                              spmSeries.isNotEmpty ? spmSeries : magnitudes,
                              Colors.deepPurple,
                            ),
                            Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Consistency',
                            '${consistency.toStringAsFixed(1)}%',
                            _buildMiniChart(
                              consistencySeries.isNotEmpty
                                  ? consistencySeries
                                  : magnitudes,
                              Colors.teal,
                            ),
                            Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total strokes',
                            totalStrokes.toString(),
                            _buildMiniBarChart(magnitudes, Colors.blue),
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Average power',
                            avgPower.toStringAsFixed(2),
                            _buildMiniChart(
                              avgPowerSeries.isNotEmpty
                                  ? avgPowerSeries
                                  : magnitudes,
                              Colors.orange,
                            ),
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Main Chart
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stroke magnitude',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: magnitudes.isEmpty
                        ? Center(
                            child: Text(
                              'No data available',
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.grey[500],
                              ),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              // Extract peaks (local maxima)
                              final peakSpots = <FlSpot>[];
                              for (int i = 0; i < magnitudes.length; i++) {
                                if (i == 0 || i == magnitudes.length - 1) {
                                  // Include first and last points
                                  if (magnitudes[i] >= 1.0) {
                                    // Transform: subtract 1.0 to make peaks start from 0 and go up
                                    peakSpots.add(
                                      FlSpot(i.toDouble(), magnitudes[i] - 1.0),
                                    );
                                  }
                                } else if (magnitudes[i] > magnitudes[i - 1] &&
                                    magnitudes[i] > magnitudes[i + 1]) {
                                  // Local maximum
                                  if (magnitudes[i] >= 1.0) {
                                    // Transform: subtract 1.0 to make peaks start from 0 and go up
                                    peakSpots.add(
                                      FlSpot(i.toDouble(), magnitudes[i] - 1.0),
                                    );
                                  }
                                }
                              }

                              // Extract troughs (local minima)
                              final troughSpots = <FlSpot>[];
                              for (int i = 0; i < magnitudes.length; i++) {
                                if (i == 0 || i == magnitudes.length - 1) {
                                  // Include first and last points
                                  if (magnitudes[i] < 1.0) {
                                    // Transform: subtract from 1.0 to make troughs negative (below 0)
                                    troughSpots.add(
                                      FlSpot(i.toDouble(), magnitudes[i] - 1.0),
                                    );
                                  }
                                } else if (magnitudes[i] < magnitudes[i - 1] &&
                                    magnitudes[i] < magnitudes[i + 1]) {
                                  // Local minimum
                                  if (magnitudes[i] < 1.0) {
                                    // Transform: subtract from 1.0 to make troughs negative (below 0)
                                    troughSpots.add(
                                      FlSpot(i.toDouble(), magnitudes[i] - 1.0),
                                    );
                                  }
                                }
                              }

                              // Calculate min and max for padding
                              final allValues = [
                                ...peakSpots.map((s) => s.y),
                                ...troughSpots.map((s) => s.y),
                              ];
                              final minY = allValues.isEmpty
                                  ? 0.0
                                  : allValues.reduce((a, b) => a < b ? a : b);
                              final maxY = allValues.isEmpty
                                  ? 2.0
                                  : allValues.reduce((a, b) => a > b ? a : b);
                              final padding =
                                  (maxY - minY) * 0.15; // 15% padding

                              return LineChart(
                                LineChartData(
                                  minY: minY - padding,
                                  maxY: maxY + padding,
                                  lineBarsData: [
                                    // Peaks line - upper boundary (above 0)
                                    if (peakSpots.isNotEmpty)
                                      LineChartBarData(
                                        spots: peakSpots,
                                        isCurved: false,
                                        isStepLineChart: true,
                                        color: Colors.blue,
                                        barWidth: 1.5,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.center,
                                            colors: [
                                              Colors.blue.withOpacity(0.3),
                                              Colors.blue.withOpacity(0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    // Troughs line - lower boundary (below 0)
                                    if (troughSpots.isNotEmpty)
                                      LineChartBarData(
                                        spots: troughSpots,
                                        isCurved: false,
                                        isStepLineChart: true,
                                        color: Colors.orange,
                                        barWidth: 1.5,
                                        dotData: const FlDotData(show: false),
                                        aboveBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.center,
                                            colors: [
                                              Colors.orange.withOpacity(0.3),
                                              Colors.orange.withOpacity(0),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: Colors.grey[300]!,
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  titlesData: FlTitlesData(show: false),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(
                                      color: Colors.grey[400]!,
                                      width: 2,
                                    ),
                                  ),
                                  lineTouchData: LineTouchData(enabled: false),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Footer
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.hasData
                      ? snapshot.data!.version
                      : '...';
                  return Text(
                    'FlowTrack v$version',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Widget chart, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          SizedBox(height: 50, child: chart),
        ],
      ),
    );
  }

  Widget _buildMiniChart(List<double> values, Color color) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: List<FlSpot>.generate(
              values.length,
              (i) => FlSpot(i.toDouble(), values[i]),
            ),
            isCurved: true,
            color: color,
            barWidth: 1,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withOpacity(0.25), color.withOpacity(0.05)],
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

  Widget _buildMiniBarChart(List<double> values, Color color) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    // Extract peaks (local maxima)
    final peakSpots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      if (i == 0 || i == values.length - 1) {
        // Include first and last points
        if (values[i] >= 1.0) {
          // Transform: subtract 1.0 to make peaks start from 0 and go up
          peakSpots.add(FlSpot(i.toDouble(), values[i] - 1.0));
        }
      } else if (values[i] > values[i - 1] && values[i] > values[i + 1]) {
        // Local maximum
        if (values[i] >= 1.0) {
          // Transform: subtract 1.0 to make peaks start from 0 and go up
          peakSpots.add(FlSpot(i.toDouble(), values[i] - 1.0));
        }
      }
    }

    // Extract troughs (local minima)
    final troughSpots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      if (i == 0 || i == values.length - 1) {
        // Include first and last points
        if (values[i] < 1.0) {
          // Transform: subtract from 1.0 to make troughs negative (below 0)
          troughSpots.add(FlSpot(i.toDouble(), values[i] - 1.0));
        }
      } else if (values[i] < values[i - 1] && values[i] < values[i + 1]) {
        // Local minimum
        if (values[i] < 1.0) {
          // Transform: subtract from 1.0 to make troughs negative (below 0)
          troughSpots.add(FlSpot(i.toDouble(), values[i] - 1.0));
        }
      }
    }

    // Calculate min and max for padding
    final allValues = [
      ...peakSpots.map((s) => s.y),
      ...troughSpots.map((s) => s.y),
    ];
    final minY = allValues.isEmpty
        ? 0.0
        : allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.isEmpty
        ? 2.0
        : allValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.2; // 20% padding for mini chart

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        lineBarsData: [
          // Peaks line - upper boundary (above 0)
          if (peakSpots.isNotEmpty)
            LineChartBarData(
              spots: peakSpots,
              isCurved: false,
              isStepLineChart: true,
              color: Colors.blue,
              barWidth: 1,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.blue.withOpacity(0),
                  ],
                ),
              ),
            ),
          // Troughs line - lower boundary (below 0)
          if (troughSpots.isNotEmpty)
            LineChartBarData(
              spots: troughSpots,
              isCurved: false,
              isStepLineChart: true,
              color: Colors.orange,
              barWidth: 1,
              dotData: const FlDotData(show: false),
              aboveBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.orange.withOpacity(0.3),
                    Colors.orange.withOpacity(0),
                  ],
                ),
              ),
            ),
        ],
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(enabled: false),
      ),
    );
  }
}
