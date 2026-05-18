import 'package:flutter/material.dart';
import '../../../../models/analytics_models.dart';

/// Lightweight bar chart for Flutter Web (no extra chart package).
class DemandForecastChart extends StatelessWidget {
  final List<MonthlyDemandPoint> historical;
  final List<MonthlyDemandPoint> forecast;

  const DemandForecastChart({
    super.key,
    required this.historical,
    required this.forecast,
  });

  @override
  Widget build(BuildContext context) {
    final histSlice = historical.length > 6
        ? historical.sublist(historical.length - 6)
        : historical;
    final display = [
      ...histSlice.map((p) => (point: p, isForecast: false)),
      ...forecast.map((p) => (point: p, isForecast: true)),
    ];

    if (display.isEmpty) {
      return Text(
        'Not enough data for chart',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }

    final maxOrders = display
        .map((e) => e.point.orderCount)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 9999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: display.map((entry) {
              final point = entry.point;
              final isForecast = entry.isForecast;
              final heightFactor = point.orderCount / maxOrders;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${point.orderCount}',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 90 * heightFactor.clamp(0.05, 1.0),
                        decoration: BoxDecoration(
                          color: isForecast
                              ? Colors.teal[300]
                              : Colors.teal[700],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        point.label.split(' ').first,
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legend(Colors.teal[700]!, 'Historical'),
            const SizedBox(width: 16),
            _legend(Colors.teal[300]!, 'Forecast'),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
      ],
    );
  }
}
