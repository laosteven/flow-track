import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
                            _buildMiniChart(magnitudes, Colors.blue),
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
                    'Magnitude over time',
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
                        : LineChart(
                            LineChartData(
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    magnitudes.length,
                                    (i) => FlSpot(i.toDouble(), magnitudes[i]),
                                  ),
                                  isCurved: true,
                                  curveSmoothness: 0.2,
                                  color: Colors.blue,
                                  barWidth: 1,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.withOpacity(0.3),
                                        Colors.blue.withOpacity(0.05),
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
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Footer
            Center(
              child: Text(
                'Generated by FlowTrack',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Widget chart) {
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
              color: Colors.grey[900],
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
}
