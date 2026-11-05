import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/dashboard_summary.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/global_refresh_mixin.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/transaction_table.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with GlobalRefreshMixin<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().load();
    });
  }

  @override
  Future<void> onGlobalRefresh() {
    return context.read<DashboardProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final summary = provider.summary;

    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Tổng quan',
                subtitle:
                    'Theo dõi nhanh tình hình tồn kho và hoạt động nhập xuất.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: provider.loading ? null : provider.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Làm mới'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/inventory'),
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: const Text('Nhập / xuất kho'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (provider.loading && summary != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (summary == null && provider.loading)
                const SectionCard(child: LoadingState())
              else if (summary == null && provider.error != null)
                SectionCard(
                  child: ErrorState(
                    message: provider.error!,
                    onRetry: provider.load,
                  ),
                )
              else if (summary != null) ...[
                if (provider.error != null) ...[
                  _ErrorBanner(
                    message: provider.error!,
                    onRetry: provider.load,
                  ),
                  const SizedBox(height: 16),
                ],
                if (summary.lowStockProducts > 0 ||
                    summary.outOfStockProducts > 0) ...[
                  _StockAlertBanner(summary: summary),
                  const SizedBox(height: 16),
                ],
                _StatsGrid(summary: summary),
                const SizedBox(height: 20),
                SectionCard(
                  title: 'Giao dịch gần đây',
                  subtitle:
                      'Các thao tác nhập xuất kho mới nhất trong hệ thống.',
                  trailing: TextButton.icon(
                    onPressed: () => context.go('/inventory'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Xem tất cả'),
                  ),
                  flush: true,
                  child: summary.recentTransactions.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Chưa có giao dịch kho',
                          message: 'Các giao dịch nhập kho và xuất kho sẽ xuất hiện tại đây.',
                        )
                      : TransactionTable(
                          transactions: summary.recentTransactions,
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1280
            ? 5
            : width >= 920
            ? 3
            : width >= 600
            ? 2
            : 1;
        const spacing = 14.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        final cards = [
          StatCard(
            label: 'Sản phẩm đang hoạt động',
            value: AppFormatters.number(summary.totalActiveProducts),
            icon: Icons.inventory_2_outlined,
            color: AppColors.primary,
            subtitle: 'Sản phẩm có thể giao dịch',
            onTap: () => context.go('/products'),
          ),
          StatCard(
            label: 'Tổng tồn kho',
            value: AppFormatters.number(summary.totalUnitsInStock),
            icon: Icons.warehouse_outlined,
            color: AppColors.secondary,
            subtitle: 'Tổng số lượng trên toàn kho',
            onTap: () => context.go('/inventory'),
          ),
          StatCard(
            label: 'Giá trị tồn kho',
            value: AppFormatters.currency(summary.inventoryValue),
            icon: Icons.payments_outlined,
            color: AppColors.info,
            subtitle: 'Theo đơn giá hiện tại',
            onTap: () => context.go('/products'),
          ),
          StatCard(
            label: 'Sắp hết hàng',
            value: AppFormatters.number(summary.lowStockProducts),
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            subtitle: 'Cần bổ sung hàng',
            onTap: () => context.go('/products'),
          ),
          StatCard(
            label: 'Hết hàng',
            value: AppFormatters.number(summary.outOfStockProducts),
            icon: Icons.error_outline_rounded,
            color: AppColors.danger,
            subtitle: 'Cần xử lý ngay',
            onTap: () => context.go('/products'),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _StockAlertBanner extends StatelessWidget {
  const _StockAlertBanner({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Có ${summary.lowStockProducts} sản phẩm sắp hết hàng và '
              '${summary.outOfStockProducts} sản phẩm đã hết hàng. '
              'Hãy kiểm tra và bổ sung hàng kịp thời.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.go('/products'),
            child: const Text('Xem sản phẩm'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

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
