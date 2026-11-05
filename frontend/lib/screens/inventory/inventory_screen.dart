import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/transaction_type.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/global_refresh_mixin.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/product_picker_field.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stock_badge.dart';
import '../../widgets/transaction_table.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.initialProductId});

  final int? initialProductId;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with GlobalRefreshMixin<InventoryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  TransactionType _type = TransactionType.stockIn;
  int? _selectedProductId;
  String? _productError;
  String? _formError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<InventoryProvider>();
      await provider.initialize(initialProductId: widget.initialProductId);
      if (!mounted) return;
      final preferredId =
          widget.initialProductId ??
          (provider.products.isNotEmpty ? provider.products.first.id : null);
      setState(() => _selectedProductId = preferredId);
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Future<void> onGlobalRefresh() async {
    final provider = context.read<InventoryProvider>();
    await provider.refresh();
    if (!mounted) return;
    if (_selectedProductId != null &&
        provider.productById(_selectedProductId) == null) {
      setState(() => _selectedProductId = null);
    }
  }

  Future<void> _submit(InventoryProvider provider) async {
    setState(() {
      _productError = _selectedProductId == null
          ? 'Vui lòng chọn sản phẩm.'
          : null;
      _formError = null;
    });

    final formValid = _formKey.currentState?.validate() ?? false;
    if (_selectedProductId == null || !formValid) return;

    final product = provider.productById(_selectedProductId);
    if (product == null) {
      setState(() => _productError = 'Sản phẩm đã chọn không còn hoạt động.');
      return;
    }

    final quantity = int.parse(_quantityController.text.trim());
    if (_type == TransactionType.stockOut && quantity > product.quantity) {
      setState(() {
        _formError =
            'Số lượng xuất (${AppFormatters.number(quantity)}) vượt quá tồn kho hiện tại (${AppFormatters.number(product.quantity)}).';
      });
      return;
    }

    setState(() => _submitting = true);

    try {
      final result = await provider.createTransaction(
        productId: product.id,
        type: _type,
        quantity: quantity,
        note: _noteController.text,
      );
      if (!mounted) return;

      final isIn = result.transaction.type.isStockIn;
      showAppSnackBar(
        context,
        'Đã ${isIn ? 'nhập' : 'xuất'} ${AppFormatters.number(result.transaction.quantity)} '
        'sản phẩm "${product.name}".',
        isSuccess: true,
      );
      _quantityController.clear();
      _noteController.clear();
      setState(() {
        _type = TransactionType.stockIn;
        _formError = null;
        _productError = null;
      });
      await provider.refresh();
      if (mounted) context.read<DashboardProvider>().refresh();
      if (mounted && provider.productById(_selectedProductId) == null) {
        setState(() => _selectedProductId = null);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _formError = error.userMessage);
      if (error.code == 'INSUFFICIENT_STOCK' ||
          error.code == 'PRODUCT_INACTIVE') {
        await provider.loadProducts();
        await provider.loadHistory();
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _formError = 'Không thể thực hiện giao dịch. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final compact = MediaQuery.sizeOf(context).width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Kho hàng',
                subtitle: 'Thực hiện nhập kho, xuất kho và tra cứu lịch sử giao dịch.',
                actions: [
                  OutlinedButton.icon(
                    onPressed:
                        provider.loadingProducts || provider.loadingHistory
                        ? null
                        : provider.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Làm mới'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1050;
                  final formCard = _StockFormCard(
                    provider: provider,
                    formKey: _formKey,
                    quantityController: _quantityController,
                    noteController: _noteController,
                    type: _type,
                    selectedProductId: _selectedProductId,
                    productError: _productError,
                    formError: _formError,
                    submitting: _submitting,
                    onTypeChanged: (value) => setState(() {
                      _type = value;
                      _formError = null;
                    }),
                    onProductChanged: (value) => setState(() {
                      _selectedProductId = value;
                      _productError = null;
                      _formError = null;
                    }),
                    onSubmit: () => _submit(provider),
                  );
                  final historyCard = _HistoryCard(provider: provider);

                  if (!wide) {
                    return Column(
                      children: [
                        formCard,
                        const SizedBox(height: 18),
                        historyCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 390, child: formCard),
                      const SizedBox(width: 18),
                      Expanded(child: historyCard),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockFormCard extends StatelessWidget {
  const _StockFormCard({
    required this.provider,
    required this.formKey,
    required this.quantityController,
    required this.noteController,
    required this.type,
    required this.selectedProductId,
    required this.productError,
    required this.formError,
    required this.submitting,
    required this.onTypeChanged,
    required this.onProductChanged,
    required this.onSubmit,
  });

  final InventoryProvider provider;
  final GlobalKey<FormState> formKey;
  final TextEditingController quantityController;
  final TextEditingController noteController;
  final TransactionType type;
  final int? selectedProductId;
  final String? productError;
  final String? formError;
  final bool submitting;
  final ValueChanged<TransactionType> onTypeChanged;
  final ValueChanged<int> onProductChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final selectedProduct = provider.productById(selectedProductId);
    final isStockOut = type == TransactionType.stockOut;

    return SectionCard(
      title: 'Tạo giao dịch kho',
      subtitle: 'Tồn kho chỉ thay đổi thông qua giao dịch nhập hoặc xuất.',
      child: provider.loadingProducts && provider.products.isEmpty
          ? const LoadingState(message: 'Đang tải sản phẩm...')
          : provider.productsError != null && provider.products.isEmpty
          ? ErrorState(
              message: provider.productsError!,
              onRetry: provider.loadProducts,
              compact: true,
            )
          : provider.products.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Chưa có sản phẩm',
              message: 'Cần có sản phẩm đang hoạt động trước khi thực hiện nhập/xuất kho.',
            )
          : Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProductPickerField(
                    products: provider.products,
                    selectedProductId: selectedProductId,
                    onChanged: onProductChanged,
                    errorText: productError,
                    enabled: !submitting,
                  ),
                  const SizedBox(height: 14),
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
                    selected: {type},
                    onSelectionChanged: submitting
                        ? null
                        : (selection) => onTypeChanged(selection.first),
                  ),
                  if (selectedProduct != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isStockOut
                            ? AppColors.warningSoft
                            : AppColors.successSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              (isStockOut
                                      ? AppColors.warning
                                      : AppColors.success)
                                  .withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isStockOut
                                ? Icons.north_east_rounded
                                : Icons.south_west_rounded,
                            size: 18,
                            color: isStockOut
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tồn kho hiện tại',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            AppFormatters.number(selectedProduct.quantity),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StockBadge(
                            status: selectedProduct.stockStatus,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: quantityController,
                    enabled: !submitting,
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
                    controller: noteController,
                    enabled: !submitting,
                    maxLines: 3,
                    maxLength: 500,
                    validator: AppValidators.note,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      hintText: 'Ví dụ: Nhập hàng từ nhà cung cấp',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 4),
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
                              formError!,
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isStockOut
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                    onPressed: submitting ? null : onSubmit,
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isStockOut
                                ? Icons.north_east_rounded
                                : Icons.south_west_rounded,
                            size: 18,
                          ),
                    label: Text(
                      isStockOut ? 'Xác nhận xuất kho' : 'Xác nhận nhập kho',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.provider});

  final InventoryProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        provider.filterProductId != null || provider.filterType != null;
    final filterProductValue =
        provider.products.any(
          (product) => product.id == provider.filterProductId,
        )
        ? provider.filterProductId
        : null;

    return SectionCard(
      title: 'Lịch sử giao dịch',
      subtitle: 'Theo dõi toàn bộ hoạt động nhập xuất kho.',
      flush: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: compact ? constraints.maxWidth : 260,
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey(
                          'history-product-${provider.filterProductId}-${provider.products.length}',
                        ),
                        initialValue: filterProductValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Lọc theo sản phẩm',
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tất cả sản phẩm'),
                          ),
                          for (final product in provider.products)
                            DropdownMenuItem<int?>(
                              value: product.id,
                              child: Text(
                                '${product.sku} • ${product.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: provider.setFilterProduct,
                      ),
                    ),
                    SizedBox(
                      width: compact ? constraints.maxWidth : 175,
                      child: DropdownButtonFormField<TransactionType?>(
                        key: ValueKey(provider.filterType),
                        initialValue: provider.filterType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Loại giao dịch',
                        ),
                        items: const [
                          DropdownMenuItem<TransactionType?>(
                            value: null,
                            child: Text('Tất cả loại'),
                          ),
                          DropdownMenuItem<TransactionType?>(
                            value: TransactionType.stockIn,
                            child: Text('Nhập kho'),
                          ),
                          DropdownMenuItem<TransactionType?>(
                            value: TransactionType.stockOut,
                            child: Text('Xuất kho'),
                          ),
                        ],
                        onChanged: provider.setFilterType,
                      ),
                    ),
                    if (hasFilters)
                      TextButton.icon(
                        onPressed: provider.clearFilters,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 17,
                        ),
                        label: const Text('Xóa bộ lọc'),
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          _HistoryResults(provider: provider),
        ],
      ),
    );
  }
}

class _HistoryResults extends StatelessWidget {
  const _HistoryResults({required this.provider});

  final InventoryProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.loadingHistory && provider.transactions.isEmpty) {
      return const LoadingState(message: 'Đang tải lịch sử giao dịch...');
    }
    if (provider.historyError != null && provider.transactions.isEmpty) {
      return ErrorState(
        message: provider.historyError!,
        onRetry: provider.loadHistory,
      );
    }
    if (provider.transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có giao dịch phù hợp',
        message: 'Thử thay đổi bộ lọc hoặc thực hiện giao dịch nhập/xuất kho đầu tiên.',
        actionLabel:
            provider.filterProductId != null || provider.filterType != null
            ? 'Xóa bộ lọc'
            : null,
        onAction:
            provider.filterProductId != null || provider.filterType != null
            ? provider.clearFilters
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.historyError != null)
          _InlineErrorBanner(
            message: provider.historyError!,
            onRetry: provider.loadHistory,
          ),
        if (provider.loadingHistory)
          const LinearProgressIndicator(minHeight: 2),
        TransactionTable(transactions: provider.transactions),
        if (provider.meta != null) ...[
          const Divider(height: 1),
          PaginationBar(
            meta: provider.meta!,
            onPageChanged: provider.setPage,
            loading: provider.loadingHistory,
          ),
        ],
      ],
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
