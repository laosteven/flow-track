import 'package:flutter/material.dart';

class StrokeRateCard extends StatelessWidget {
  final double strokeRate;
  
  const StrokeRateCard({
    super.key,
    required this.strokeRate,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'STROKE RATE',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  strokeRate.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: _getColorForRate(strokeRate),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SPM',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getRateDescription(strokeRate),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getColorForRate(double rate) {
    if (rate < 40) return Colors.blue;
    if (rate < 60) return Colors.green;
    if (rate < 80) return Colors.orange;
    return Colors.red;
  }
  
  String _getRateDescription(double rate) {
    if (rate < 40) return 'Warm-up pace';
    if (rate < 60) return 'Training pace';
    if (rate < 80) return 'Race pace';
    return 'Sprint!';
  }
}
