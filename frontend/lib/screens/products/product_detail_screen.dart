import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../../models/transaction_type.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/product_detail_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/global_refresh_mixin.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stock_badge.dart';
import '../../widgets/stock_movement_dialog.dart';
import '../../widgets/transaction_table.dart';
import 'product_form_dialog.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with GlobalRefreshMixin<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductDetailProvider>().load(widget.productId);
      }
    });
  }

  @override
  Future<void> onGlobalRefresh() {
    return context.read<ProductDetailProvider>().refresh();
  }

  Future<void> _openEdit(Product product) async {
    final saved = await showProductFormDialog(context, product: product);
    if (!mounted || saved != true) return;
    showAppSnackBar(context, 'Đã cập nhật sản phẩm.', isSuccess: true);
    await context.read<ProductDetailProvider>().refresh();
    if (mounted) context.read<DashboardProvider>().refresh();
  }

  Future<void> _openStockMovement(Product product, TransactionType type) async {
    final result = await showStockMovementDialog(
      context,
      product: product,
      initialType: type,
    );
    if (!mounted || result == null) return;

    final isIn = result.transaction.type.isStockIn;
    showAppSnackBar(
      context,
      'Đã ${isIn ? 'nhập' : 'xuất'} ${AppFormatters.number(result.transaction.quantity)} '
      'sản phẩm "${product.name}".',
      isSuccess: true,
    );
    await context.read<ProductDetailProvider>().refresh();
    if (mounted) context.read<DashboardProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductDetailProvider>();
    final product = provider.product;
    final compact = MediaQuery.sizeOf(context).width < 700;

    if (provider.loading && product == null) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(28),
        child: LoadingState(message: 'Đang tải chi tiết sản phẩm...'),
      );
    }

    if (provider.notFound) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: SectionCard(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Không tìm thấy sản phẩm',
            message: 'Sản phẩm không tồn tại hoặc đã ngừng hoạt động. Vui lòng quay lại danh sách sản phẩm.',
            actionLabel: 'Quay lại danh sách',
            onAction: () => context.go('/products'),
          ),
        ),
      );
    }

    if (provider.error != null && product == null) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: SectionCard(
          child: ErrorState(
            message: provider.error!,
            onRetry: () =>
                context.read<ProductDetailProvider>().load(widget.productId),
          ),
        ),
      );
    }

    if (product == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: product.name,
                subtitle: '${product.sku} • ${product.categoryName}',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/products'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Quay lại'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openEdit(product),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Chỉnh sửa'),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        _openStockMovement(product, TransactionType.stockIn),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nhập kho'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (provider.loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (provider.error != null) ...[
                _InlineErrorBanner(
                  message: provider.error!,
                  onRetry: () => context.read<ProductDetailProvider>().load(
                    widget.productId,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final infoCard = SectionCard(
                    title: 'Thông tin sản phẩm',
                    subtitle: 'Dữ liệu nhận trực tiếp từ hệ thống quản lý kho.',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Mã SKU', value: product.sku),
                        _InfoRow(label: 'Tên sản phẩm', value: product.name),
                        _InfoRow(
                          label: 'Danh mục',
                          value: product.categoryName,
                        ),
                        _InfoRow(
                          label: 'Đơn giá',
                          value: AppFormatters.currency(product.unitPrice),
                        ),
                        _InfoRow(
                          label: 'Mức tồn tối thiểu',
                          value:
                              '${AppFormatters.number(product.reorderLevel)} sản phẩm',
                        ),
                        _InfoRow(
                          label: 'Ngày tạo',
                          value: AppFormatters.dateTime(product.createdAt),
                          isLast: true,
                        ),
                      ],
                    ),
                  );

                  final stockCard = SectionCard(
                    title: 'Tình trạng tồn kho',
                    subtitle: 'Tồn kho hiện tại và thao tác nhanh.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Số lượng hiện có',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppFormatters.number(product.quantity),
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'sản phẩm',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              StockBadge(status: product.stockStatus),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          onPressed: () => _openStockMovement(
                            product,
                            TransactionType.stockIn,
                          ),
                          icon: const Icon(Icons.south_west_rounded, size: 18),
                          label: const Text('Nhập kho'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _openStockMovement(
                            product,
                            TransactionType.stockOut,
                          ),
                          icon: const Icon(Icons.north_east_rounded, size: 18),
                          label: const Text('Xuất kho'),
                        ),
                      ],
                    ),
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        infoCard,
                        const SizedBox(height: 16),
                        stockCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: infoCard),
                      const SizedBox(width: 16),
                      Expanded(child: stockCard),
                    ],
                  );
                },
              ),
              if (product.description != null) ...[
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Mô tả sản phẩm',
                  child: Text(
                    product.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SectionCard(
                title: 'Lịch sử giao dịch',
                subtitle: '10 giao dịch kho gần nhất của sản phẩm này.',
                trailing: TextButton.icon(
                  onPressed: () =>
                      context.go('/inventory?productId=${product.id}'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Xem tất cả'),
                ),
                flush: true,
                child: provider.transactions.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Chưa có giao dịch',
                        message: 'Sản phẩm này chưa có lịch sử nhập kho hoặc xuất kho.',
                      )
                    : TransactionTable(
                        transactions: provider.transactions,
                        showProduct: false,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 19,
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
