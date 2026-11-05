import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/pagination_meta.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.meta,
    required this.onPageChanged,
    this.loading = false,
  });

  final PaginationMeta meta;
  final ValueChanged<int> onPageChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (meta.total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            'Hiển thị ${AppFormatters.number(meta.firstItem)}–'
            '${AppFormatters.number(meta.lastItem)} trong '
            '${AppFormatters.number(meta.total)} kết quả',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Trang trước',
                onPressed: meta.hasPrev && !loading
                    ? () => onPageChanged(meta.page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Trang ${meta.page}/${meta.totalPages == 0 ? 1 : meta.totalPages}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Trang sau',
                onPressed: meta.hasNext && !loading
                    ? () => onPageChanged(meta.page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
