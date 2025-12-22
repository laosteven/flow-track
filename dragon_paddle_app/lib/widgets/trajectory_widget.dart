import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/sensor_data.dart';

/// Widget to display 3D trajectory of paddle motion
/// Uses 2D projections for visualization
class TrajectoryWidget extends StatelessWidget {
  final List<TrajectoryPoint> trajectoryPoints;

  const TrajectoryWidget({super.key, required this.trajectoryPoints});

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
                const Icon(Icons.timeline, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  '3D Trajectory',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: trajectoryPoints.isEmpty
                  ? Center(
                      child: Text(
                        'Start paddling to see trajectory',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildProjection(
                            context,
                            'XY plane (top view)',
                            (p) => Offset(p.x, p.y),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildProjection(
                            context,
                            'XZ plane (side view)',
                            (p) => Offset(p.x, p.z),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${trajectoryPoints.length} trajectory points',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjection(
    BuildContext context,
    String title,
    Offset Function(TrajectoryPoint) projection,
  ) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: TrajectoryPainter(
                points: trajectoryPoints,
                projection: projection,
              ),
              child: Container(),
            ),
          ),
        ),
      ],
    );
  }
}

class TrajectoryPainter extends CustomPainter {
  final List<TrajectoryPoint> points;
  final Offset Function(TrajectoryPoint) projection;

  TrajectoryPainter({required this.points, required this.projection});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Find bounds for normalization
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final point in points) {
      final offset = projection(point);
      minX = math.min(minX, offset.dx);
      maxX = math.max(maxX, offset.dx);
      minY = math.min(minY, offset.dy);
      maxY = math.max(maxY, offset.dy);
    }

    // Add padding
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final padding = 20.0;

    // Normalize and draw path
    final path = Path();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length; i++) {
      final offset = projection(points[i]);

      // Normalize to canvas size
      final x = rangeX > 0
          ? padding + (offset.dx - minX) / rangeX * (size.width - 2 * padding)
          : size.width / 2;
      final y = rangeY > 0
          ? padding + (offset.dy - minY) / rangeY * (size.height - 2 * padding)
          : size.height / 2;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Color gradient from blue (start) to red (end)
      paint.color = Color.lerp(Colors.blue, Colors.red, i / points.length)!;

      // Draw point
      canvas.drawCircle(Offset(x, y), 2, paint);
    }

    // Draw connecting lines
    paint.color = Colors.grey.withValues(alpha: 0.5);
    paint.strokeWidth = 1.0;
    canvas.drawPath(path, paint);

    // Draw center cross
    final centerPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(TrajectoryPainter oldDelegate) {
    return points != oldDelegate.points;
  }
}
