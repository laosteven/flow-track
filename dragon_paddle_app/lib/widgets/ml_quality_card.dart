import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Widget to display ML-based stroke quality classifications
class MLQualityCard extends StatelessWidget {
  final MLClassifications ml;

  const MLQualityCard({
    super.key,
    required this.ml,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'AI Stroke Analysis',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildOverallScore(context),
            const SizedBox(height: 16),
            _buildQualityBar(
              context,
              label: 'Clean Stroke',
              score: ml.cleanStrokeScore,
              icon: Icons.check_circle,
              goodDesc: 'Clean',
              badDesc: 'Messy',
            ),
            const SizedBox(height: 12),
            _buildQualityBar(
              context,
              label: 'Rotation',
              score: ml.rotationQuality,
              icon: Icons.rotate_right,
              goodDesc: 'Proper',
              badDesc: 'Over-rotation',
            ),
            const SizedBox(height: 12),
            _buildQualityBar(
              context,
              label: 'Paddle Angle',
              score: ml.angleQuality,
              icon: Icons.straighten,
              goodDesc: 'Optimal',
              badDesc: 'Incorrect',
            ),
            const SizedBox(height: 12),
            _buildQualityBar(
              context,
              label: 'Exit Timing',
              score: ml.exitQuality,
              icon: Icons.eject,
              goodDesc: 'Full stroke',
              badDesc: 'Early exit',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallScore(BuildContext context) {
    final overall = ml.overallQuality;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getQualityColor(overall).withOpacity(0.3),
            _getQualityColor(overall).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getQualityColor(overall),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Overall Quality',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${(overall * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getQualityColor(overall),
                ),
          ),
          Text(
            ml.qualityDescription,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getQualityColor(overall),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBar(
    BuildContext context, {
    required String label,
    required double score,
    required IconData icon,
    required String goodDesc,
    required String badDesc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: _getQualityColor(score)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Text(
              score > 0.5 ? goodDesc : badDesc,
              style: TextStyle(
                fontSize: 12,
                color: _getQualityColor(score),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getQualityColor(score)),
          ),
        ),
      ],
    );
  }

  Color _getQualityColor(double score) {
    if (score > 0.8) return Colors.green;
    if (score > 0.6) return Colors.lightGreen;
    if (score > 0.4) return Colors.orange;
    return Colors.red;
  }
}
