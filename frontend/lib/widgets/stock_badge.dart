import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/stock_status.dart';

class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.status, this.compact = false});

  final StockStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StockStatus.inStock => AppColors.success,
      StockStatus.lowStock => AppColors.warning,
      StockStatus.outOfStock => AppColors.danger,
    };
    final background = switch (status) {
      StockStatus.inStock => AppColors.successSoft,
      StockStatus.lowStock => AppColors.warningSoft,
      StockStatus.outOfStock => AppColors.dangerSoft,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
