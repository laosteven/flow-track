import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Widget to display advanced stroke metrics
class AdvancedMetricsCard extends StatelessWidget {
  final AdvancedMetrics metrics;

  const AdvancedMetricsCard({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced metrics',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              context,
              icon: Icons.straighten,
              label: 'Stroke length',
              value: '${metrics.strokeLength.toStringAsFixed(1)} units',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildMetricRow(
              context,
              icon: Icons.rotate_right,
              label: 'Entry → exit angle',
              value:
                  '${metrics.entryAngle.toStringAsFixed(0)}° → ${metrics.exitAngle.toStringAsFixed(0)}°',
              color: Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildMetricRow(
              context,
              icon: Icons.show_chart,
              label: 'Smoothness',
              value: _getSmoothnessText(metrics.smoothness),
              color: _getSmoothnessColor(metrics.smoothness),
            ),
            const SizedBox(height: 12),
            _buildMetricRow(
              context,
              icon: Icons.rotate_90_degrees_ccw,
              label: 'Rotation torque',
              value: '${metrics.rotationTorque.toStringAsFixed(1)}',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildMetricRow(
              context,
              icon: Icons.battery_alert,
              label: 'Fatigue',
              value: _getFatigueText(metrics.fatigueScore),
              color: _getFatigueColor(metrics.fatigueScore),
            ),
            const SizedBox(height: 12),
            _buildMetricRow(
              context,
              icon: Icons.compare_arrows,
              label: 'L/R balance',
              value: _getAsymmetryText(metrics.asymmetryRatio),
              color: _getAsymmetryColor(metrics.asymmetryRatio),
            ),
            const SizedBox(height: 12),
            _buildPhaseIndicator(
              context,
              metrics.strokePhase,
              metrics.phaseString,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator(
    BuildContext context,
    int phase,
    String phaseString,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _getPhaseColor(phase).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getPhaseColor(phase), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getPhaseIcon(phase), color: _getPhaseColor(phase)),
          const SizedBox(width: 8),
          Text(
            'Phase: $phaseString',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getPhaseColor(phase),
            ),
          ),
        ],
      ),
    );
  }

  String _getSmoothnessText(double smoothness) {
    if (smoothness > 0.8)
      return '${(smoothness * 100).toStringAsFixed(0)}% Excellent';
    if (smoothness > 0.6)
      return '${(smoothness * 100).toStringAsFixed(0)}% Good';
    if (smoothness > 0.4)
      return '${(smoothness * 100).toStringAsFixed(0)}% Fair';
    return '${(smoothness * 100).toStringAsFixed(0)}% Poor';
  }

  Color _getSmoothnessColor(double smoothness) {
    if (smoothness > 0.8) return Colors.green;
    if (smoothness > 0.6) return Colors.lightGreen;
    if (smoothness > 0.4) return Colors.orange;
    return Colors.red;
  }

  String _getFatigueText(double fatigue) {
    if (fatigue < 0.2) return '${(fatigue * 100).toStringAsFixed(0)}% Fresh';
    if (fatigue < 0.4) return '${(fatigue * 100).toStringAsFixed(0)}% Mild';
    if (fatigue < 0.6) return '${(fatigue * 100).toStringAsFixed(0)}% Moderate';
    return '${(fatigue * 100).toStringAsFixed(0)}% High';
  }

  Color _getFatigueColor(double fatigue) {
    if (fatigue < 0.2) return Colors.green;
    if (fatigue < 0.4) return Colors.lightGreen;
    if (fatigue < 0.6) return Colors.orange;
    return Colors.red;
  }

  String _getAsymmetryText(double ratio) {
    final leftPercent = (ratio * 100).toStringAsFixed(0);
    final rightPercent = ((1 - ratio) * 100).toStringAsFixed(0);
    return 'L:$leftPercent% R:$rightPercent%';
  }

  Color _getAsymmetryColor(double ratio) {
    // Balanced is around 0.5
    final deviation = (ratio - 0.5).abs();
    if (deviation < 0.1) return Colors.green; // Within 10%
    if (deviation < 0.2) return Colors.orange; // Within 20%
    return Colors.red; // More than 20% imbalance
  }

  IconData _getPhaseIcon(int phase) {
    switch (phase) {
      case 0:
        return Icons.stop_circle;
      case 1:
        return Icons.water_drop;
      case 2:
        return Icons.flash_on;
      case 3:
        return Icons.eject;
      case 4:
        return Icons.replay;
      default:
        return Icons.help;
    }
  }

  Color _getPhaseColor(int phase) {
    switch (phase) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
