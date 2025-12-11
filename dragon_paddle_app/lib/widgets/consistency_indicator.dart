import 'package:flutter/material.dart';

class ConsistencyIndicator extends StatelessWidget {
  final double consistency;
  final bool compact;
  final VoidCallback? onInfo;
  
  const ConsistencyIndicator({
    super.key,
    required this.consistency,
    this.compact = false,
    this.onInfo,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _getIconForConsistency(consistency),
                  size: compact ? 28 : 40,
                  color: _getColorForConsistency(consistency),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Consistency',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onInfo != null) IconButton(icon: const Icon(Icons.info_outline, size: 18), onPressed: onInfo),
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
