import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/network/api_exception.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../core/utils/validators.dart';
import '../models/product.dart';
import '../models/stock_movement_result.dart';
import '../models/transaction_type.dart';
import '../services/inventory_service.dart';
import 'stock_badge.dart';

Future<StockMovementResult?> showStockMovementDialog(
  BuildContext context, {
  required Product product,
  TransactionType initialType = TransactionType.stockIn,
}) {
  return showDialog<StockMovementResult>(
    context: context,
    builder: (context) {
      return _StockMovementDialog(product: product, initialType: initialType);
    },
  );
}

class _StockMovementDialog extends StatefulWidget {
  const _StockMovementDialog({
    required this.product,
    required this.initialType,
  });

  final Product product;
  final TransactionType initialType;

  @override
  State<_StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<_StockMovementDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late TransactionType _type;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = int.parse(_quantityController.text.trim());
    if (_type == TransactionType.stockOut &&
        quantity > widget.product.quantity) {
      setState(() {
        _error =
            'Số lượng xuất (${AppFormatters.number(quantity)}) vượt quá tồn kho hiện tại (${AppFormatters.number(widget.product.quantity)}).';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await context.read<InventoryService>().createTransaction(
        productId: widget.product.id,
        type: _type,
        quantity: quantity,
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.userMessage);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Không thể thực hiện giao dịch. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStockOut = _type == TransactionType.stockOut;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isStockOut
                            ? AppColors.warningSoft
                            : AppColors.successSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isStockOut
                            ? Icons.north_east_rounded
                            : Icons.south_west_rounded,
                        color: isStockOut
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isStockOut ? 'Xuất kho' : 'Nhập kho',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            widget.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.stockIn,
                      label: Text('Nhập kho'),
                      icon: Icon(Icons.add_rounded),
                    ),
                    ButtonSegment(
                      value: TransactionType.stockOut,
                      label: Text('Xuất kho'),
                      icon: Icon(Icons.remove_rounded),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: _submitting
                      ? null
                      : (selection) => setState(() => _type = selection.first),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      const Text('Tồn kho hiện tại'),
                      const Spacer(),
                      Text(
                        AppFormatters.number(widget.product.quantity),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StockBadge(
                        status: widget.product.stockStatus,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: AppValidators.quantity,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng *',
                    hintText: 'Nhập số lượng',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteController,
                  enabled: !_submitting,
                  maxLines: 3,
                  maxLength: 500,
                  validator: AppValidators.note,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    hintText: 'Ví dụ: Nhập hàng từ nhà cung cấp',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isStockOut
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isStockOut
                                  ? 'Xác nhận xuất kho'
                                  : 'Xác nhận nhập kho',
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
