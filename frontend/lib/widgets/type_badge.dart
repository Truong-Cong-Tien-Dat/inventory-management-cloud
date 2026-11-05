import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/transaction_type.dart';

class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type, this.compact = false});

  final TransactionType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = type.isStockIn ? AppColors.success : AppColors.warning;
    final background = type.isStockIn
        ? AppColors.successSoft
        : AppColors.warningSoft;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type.isStockIn
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
            size: compact ? 13 : 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            type.isStockIn ? 'Nhập' : 'Xuất',
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
