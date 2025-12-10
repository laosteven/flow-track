import 'package:flutter/material.dart';

class ConsistencyIndicator extends StatelessWidget {
  final double consistency;
  
  const ConsistencyIndicator({
    super.key,
    required this.consistency,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getIconForConsistency(consistency),
                  size: 40,
                  color: _getColorForConsistency(consistency),
                ),
                const SizedBox(width: 12),
                Text(
                  'Consistency',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: consistency / 100,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getColorForConsistency(consistency),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getDescriptionForConsistency(consistency),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _getColorForConsistency(consistency),
                  ),
                ),
                Text(
                  '${consistency.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getColorForConsistency(consistency),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getColorForConsistency(double consistency) {
    if (consistency >= 80) return Colors.green;
    if (consistency >= 60) return Colors.orange;
    return Colors.red;
  }
  
  IconData _getIconForConsistency(double consistency) {
    if (consistency >= 80) return Icons.check_circle;
    if (consistency >= 60) return Icons.warning;
    return Icons.error;
  }
  
  String _getDescriptionForConsistency(double consistency) {
    if (consistency >= 80) return 'Excellent';
    if (consistency >= 60) return 'Good';
    return 'Needs Work';
  }
}
