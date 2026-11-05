import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/inventory_transaction.dart';
import 'type_badge.dart';

class TransactionTable extends StatelessWidget {
  const TransactionTable({
    super.key,
    required this.transactions,
    this.showProduct = true,
  });

  final List<InventoryTransaction> transactions;
  final bool showProduct;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (var index = 0; index < transactions.length; index++) ...[
                TransactionCard(
                  transaction: transactions[index],
                  showProduct: showProduct,
                ),
                if (index != transactions.length - 1) const Divider(height: 1),
              ],
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 58,
            dataRowMaxHeight: 66,
            horizontalMargin: 20,
            columnSpacing: 22,
            headingRowColor: const WidgetStatePropertyAll(
              AppColors.surfaceMuted,
            ),
            border: const TableBorder(
              horizontalInside: BorderSide(color: AppColors.border),
            ),
            columns: [
              const DataColumn(label: Text('Thời gian')),
              if (showProduct) const DataColumn(label: Text('Sản phẩm')),
              const DataColumn(label: Text('Loại')),
              const DataColumn(label: Text('Số lượng')),
              const DataColumn(label: Text('Ghi chú')),
            ],
            rows: transactions.map((transaction) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      AppFormatters.dateTime(transaction.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (showProduct)
                    DataCell(
                      SizedBox(
                        width: 190,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              transaction.productSku,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  DataCell(TypeBadge(type: transaction.type, compact: true)),
                  DataCell(
                    Text(
                      '${transaction.type.isStockIn ? '+' : '-'}${AppFormatters.number(transaction.quantity)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: transaction.type.isStockIn
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 220,
                      child: Text(
                        transaction.note ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.showProduct = true,
  });

  final InventoryTransaction transaction;
  final bool showProduct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: transaction.type.isStockIn
                  ? AppColors.successSoft
                  : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              transaction.type.isStockIn
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              size: 19,
              color: transaction.type.isStockIn
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        showProduct
                            ? transaction.productName
                            : transaction.type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TypeBadge(type: transaction.type, compact: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${transaction.productSku} • ${AppFormatters.dateTime(transaction.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (transaction.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaction.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${transaction.type.isStockIn ? '+' : '-'}${AppFormatters.number(transaction.quantity)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: transaction.type.isStockIn
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
