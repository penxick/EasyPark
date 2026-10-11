import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/ui_kit.dart';
import '../models/admin_summary.dart';

class AdminStatusChart extends StatelessWidget {
  const AdminStatusChart({super.key, required this.data});
  final AdminSummary data;
  @override
  Widget build(BuildContext context) {
    final values = [
      data.freeSpaces,
      data.occupiedSpaces,
      data.reservedSpaces,
      data.unavailableSpaces,
    ];
    const labels = ['Свободно', 'Занято', 'Забронировано', 'Недоступно'];
    return AppCard(
      title: 'Распределение статусов мест',
      child: Column(
        children: [
          if (data.totalSpaces == 0)
            const Text('Парковочных мест пока нет')
          else
            SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(painter: _StatusPainter(values)),
            ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < values.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 12, height: 12, color: _colors[i]),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${labels[i]}: ${values[i]}')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

const _colors = [
  AppColors.free,
  AppColors.occupied,
  AppColors.reserved,
  AppColors.mutedForeground,
];

class _StatusPainter extends CustomPainter {
  _StatusPainter(this.values);
  final List<int> values;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;
    var start = -math.pi / 2;
    final rect = Offset.zero & size;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(
        rect.deflate(4),
        start,
        sweep,
        true,
        Paint()..color = _colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _StatusPainter oldDelegate) => List.generate(
    values.length,
    (i) => values[i] != oldDelegate.values[i],
  ).contains(true);
}

class AdminAnalyticsBar extends StatelessWidget {
  const AdminAnalyticsBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
  });
  final String label, value;
  final double fraction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label — $value'),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: fraction,
          minHeight: 10,
          backgroundColor: AppColors.secondary,
          color: AppColors.primary,
          semanticsLabel: label,
          semanticsValue: value,
        ),
      ],
    ),
  );
}
