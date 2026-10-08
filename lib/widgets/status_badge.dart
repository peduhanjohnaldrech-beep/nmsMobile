import 'package:flutter/material.dart';
import '../models/assessment_model.dart';

/// Compact colored badge that shows a nutritional status code.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool   large;

  const StatusBadge({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = nutritionStatusColor(status);
    final label = status.isEmpty ? '—' : status;
    final fontSize  = large ? 13.0 : 11.0;
    final padH      = large ? 10.0 :  7.0;
    final padV      = large ?  5.0 :  3.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        border:       Border.all(color: color.withValues(alpha: 0.6), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Full-width status chip with label and color
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = nutritionStatusColor(status);
    final label = nutritionStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        border:       Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$status — $label',
            style: TextStyle(
              color:      color,
              fontWeight: FontWeight.w600,
              fontSize:   14,
            ),
          ),
        ],
      ),
    );
  }
}
