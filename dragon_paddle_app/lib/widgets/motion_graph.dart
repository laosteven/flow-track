import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sensor_data.dart';

class MotionGraph extends StatelessWidget {
  final List<AccelerometerData> data;
  final bool compact;
  final VoidCallback? onInfo;
  final double height;
  
  const MotionGraph({
    super.key,
    required this.data,
    this.compact = false,
    this.onInfo,
    this.height = 200,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Motion Pattern',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onInfo != null) IconButton(icon: const Icon(Icons.info_outline, size: 18), onPressed: onInfo),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: data.isEmpty
                  ? const Center(
                      child: Text('Waiting for data...'),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 5,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade300,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toStringAsFixed(0),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        lineBarsData: [
                          // X-axis line
                          LineChartBarData(
                            spots: _getSpots(data, 'x'),
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                          // Y-axis line
                          LineChartBarData(
                            spots: _getSpots(data, 'y'),
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                          // Z-axis line
                          LineChartBarData(
                            spots: _getSpots(data, 'z'),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                        minY: -10,
                        maxY: 10,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('X', Colors.red),
                const SizedBox(width: 16),
                _buildLegendItem('Y', Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem('Z', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  List<FlSpot> _getSpots(List<AccelerometerData> data, String axis) {
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final value = axis == 'x'
          ? data[i].x
          : axis == 'y'
              ? data[i].y
              : data[i].z;
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
