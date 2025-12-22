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

  const SessionReportWidget({
    super.key,
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
                  fontSize: 20,
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
            const SizedBox(height: 4),
            Divider(thickness: 1, color: Colors.grey[300]),
            const SizedBox(height: 4),

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
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total strokes',
                            totalStrokes.toString(),
                            _buildMiniChart(magnitudes, Colors.blue),
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Distance',
                            '${distance.toStringAsFixed(0)} m',
                            _buildMiniChart(
                              distanceSeries.isNotEmpty
                                  ? distanceSeries
                                  : magnitudes,
                              Colors.green,
                            ),
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Speed',
                            '${speed.toStringAsFixed(2)} m/s',
                            _buildMiniChart(
                              speedSeries.isNotEmpty ? speedSeries : magnitudes,
                              Colors.purple,
                            ),
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Split (500m)',
                      split500m > 0
                          ? '${split500m.floor()}:${((split500m % 1) * 60).round().toString().padLeft(2, '0')} min'
                          : '—',
                      _buildMiniChart(
                        split500mSeries.isNotEmpty
                            ? split500mSeries
                            : magnitudes,
                        Colors.red,
                      ),
                      Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Stroke magnitude',
                      '',
                      _buildMiniBarChart(magnitudes, Colors.indigo),
                      Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

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
          if (value.isNotEmpty) ...[
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
          if (value.isEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(height: 80, child: chart),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniChart(List<double> values, Color color) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Find max and min indices and values
    int maxIndex = 0;
    int minIndex = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[maxIndex]) maxIndex = i;
      if (values[i] < values[minIndex]) minIndex = i;
    }
    
    final maxValue = values[maxIndex];
    final minValue = values[minIndex];
    
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
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                // Only show dots for max and min points
                return spot.x == maxIndex.toDouble() || spot.x == minIndex.toDouble();
              },
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2.5,
                  color: spot.x == maxIndex.toDouble() ? Colors.green : Colors.red,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            // Max value line
            HorizontalLine(
              y: maxValue,
              color: Colors.transparent,
              strokeWidth: 0,
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 2, bottom: 2),
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                labelResolver: (line) => maxValue.toStringAsFixed(1),
              ),
            ),
            // Min value line
            HorizontalLine(
              y: minValue,
              color: Colors.transparent,
              strokeWidth: 0,
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.only(right: 2, top: 2),
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                labelResolver: (line) => minValue.toStringAsFixed(1),
              ),
            ),
          ],
        ),
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
                    Colors.blue.withValues(alpha: 0.3),
                    Colors.blue.withValues(alpha: 0),
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
                    Colors.orange.withValues(alpha: 0.3),
                    Colors.orange.withValues(alpha: 0),
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
