import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Widget to display temperature and environment data
class TemperatureCard extends StatelessWidget {
  final TemperatureData temperature;

  const TemperatureCard({super.key, required this.temperature});

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
                Icon(
                  temperature.isInWater ? Icons.water : Icons.air,
                  color: temperature.isInWater ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Environment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTempDisplay(context),
            if (temperature.isHighTemp) ...[
              const SizedBox(height: 12),
              _buildWarning(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTempDisplay(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Icon(
              Icons.thermostat,
              color: _getTempColor(temperature.temperature),
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              '${temperature.temperature.toStringAsFixed(1)}°C',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getTempColor(temperature.temperature),
              ),
            ),
            Text('Temperature', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Column(
          children: [
            Icon(
              Icons.water_drop,
              color: _getHumidityColor(temperature.humidity),
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              '${temperature.humidity.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getHumidityColor(temperature.humidity),
              ),
            ),
            Text('Humidity', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High temperature warning',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stay hydrated! Temperature is above 35°C',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTempColor(double temp) {
    if (temp > 35) return Colors.red;
    if (temp > 30) return Colors.orange;
    if (temp > 25) return Colors.amber;
    if (temp > 20) return Colors.green;
    if (temp > 15) return Colors.lightBlue;
    return Colors.blue;
  }

  Color _getHumidityColor(double humidity) {
    if (humidity > 80) return Colors.blue;
    if (humidity > 60) return Colors.lightBlue;
    if (humidity > 40) return Colors.amber;
    return Colors.orange;
  }
}
