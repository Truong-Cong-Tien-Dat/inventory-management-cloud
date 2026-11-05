import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/product.dart';
import 'stock_badge.dart';

class ProductTable extends StatelessWidget {
  const ProductTable({
    super.key,
    required this.products,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Product> products;
  final ValueChanged<Product> onOpen;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 50,
        dataRowMinHeight: 62,
        dataRowMaxHeight: 76,
        horizontalMargin: 20,
        columnSpacing: 24,
        headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceMuted),
        border: const TableBorder(
          horizontalInside: BorderSide(color: AppColors.border),
        ),
        columns: const [
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Sản phẩm')),
          DataColumn(label: Text('Danh mục')),
          DataColumn(label: Text('Đơn giá')),
          DataColumn(label: Text('Tồn kho')),
          DataColumn(label: Text('Trạng thái')),
          DataColumn(label: Text('Thao tác')),
        ],
        rows: products.map((product) {
          return DataRow(
            onSelectChanged: (_) => onOpen(product),
            cells: [
              DataCell(
                Text(
                  product.sku,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    fontSize: 13,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 210,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (product.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              DataCell(
                Text(
                  product.categoryName,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              DataCell(
                Text(
                  AppFormatters.currency(product.unitPrice),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(
                Text(
                  AppFormatters.number(product.quantity),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              DataCell(StockBadge(status: product.stockStatus, compact: true)),
              DataCell(
                _ProductActions(
                  onEdit: onEdit,
                  onDelete: onDelete,
                  product: product,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ProductActions extends StatelessWidget {
  const _ProductActions({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Thao tác',
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit(product);
        } else if (value == 'delete') {
          onDelete(product);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Chỉnh sửa'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.danger,
              ),
              SizedBox(width: 10),
              Text('Xóa sản phẩm', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
    );
  }
}
