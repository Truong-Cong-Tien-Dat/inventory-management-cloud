import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/product.dart';
import 'stock_badge.dart';

class ProductPickerField extends StatelessWidget {
  const ProductPickerField({
    super.key,
    required this.products,
    required this.selectedProductId,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.label = 'Sản phẩm',
  });

  final List<Product> products;
  final int? selectedProductId;
  final ValueChanged<int> onChanged;
  final String? errorText;
  final bool enabled;
  final String label;

  Product? get _selected {
    for (final product in products) {
      if (product.id == selectedProductId) return product;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final canOpen = enabled && products.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 7),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: canOpen
              ? () async {
                  final selectedId = await showProductPicker(
                    context,
                    products: products,
                    selectedProductId: selectedProductId,
                  );
                  if (selectedId != null) onChanged(selectedId);
                }
              : null,
          child: InputDecorator(
            isEmpty: selected == null,
            decoration: InputDecoration(
              errorText: errorText,
              enabled: enabled,
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            child: selected == null
                ? Text(
                    products.isEmpty
                        ? 'Chưa có sản phẩm để lựa chọn'
                        : 'Chọn sản phẩm...',
                    style: const TextStyle(color: AppColors.textMuted),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${selected.sku} • Tồn: ${AppFormatters.number(selected.quantity)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StockBadge(status: selected.stockStatus, compact: true),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

Future<int?> showProductPicker(
  BuildContext context, {
  required List<Product> products,
  int? selectedProductId,
}) {
  if (products.isEmpty) return Future.value(null);
  final content = _ProductPickerContent(
    products: products,
    selectedProductId: selectedProductId,
  );
  final isWide = MediaQuery.sizeOf(context).width >= 720;

  if (isWide) {
    return showDialog<int>(
      context: context,
      builder: (context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
            child: content,
          ),
        );
      },
    );
  }

  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: content,
      );
    },
  );
}

class _ProductPickerContent extends StatefulWidget {
  const _ProductPickerContent({
    required this.products,
    required this.selectedProductId,
  });

  final List<Product> products;
  final int? selectedProductId;

  @override
  State<_ProductPickerContent> createState() => _ProductPickerContentState();
}

class _ProductPickerContentState extends State<_ProductPickerContent> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.products;
    return widget.products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Chọn sản phẩm',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Tìm theo tên hoặc SKU...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Không tìm thấy sản phẩm phù hợp.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final selected = product.id == widget.selectedProductId;
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(product.id),
                      title: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${product.sku} • Tồn: ${AppFormatters.number(product.quantity)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StockBadge(
                            status: product.stockStatus,
                            compact: true,
                          ),
                          if (selected) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
