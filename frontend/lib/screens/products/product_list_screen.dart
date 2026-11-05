import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/product_list_provider.dart';
import '../../services/product_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/global_refresh_mixin.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_table.dart';
import '../../widgets/section_card.dart';
import 'product_form_dialog.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, this.initialCategoryId});

  final int? initialCategoryId;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen>
    with GlobalRefreshMixin<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static const _sortOptions = <String, String>{
    'createdAt': 'Mới nhất',
    'name': 'Tên sản phẩm',
    'unitPrice': 'Đơn giá',
    'quantity': 'Tồn kho',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final categoryProvider = context.read<CategoryProvider>();
      final provider = context.read<ProductListProvider>();
      _searchController.text = provider.search;
      categoryProvider.load();

      if (widget.initialCategoryId != null) {
        if (provider.categoryId == widget.initialCategoryId) {
          await provider.refresh();
        } else {
          await provider.setCategory(widget.initialCategoryId);
        }
      } else {
        await provider.load();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Future<void> onGlobalRefresh() async {
    await Future.wait([
      context.read<ProductListProvider>().refresh(),
      context.read<CategoryProvider>().load(force: true),
    ]);
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<ProductListProvider>().setSearch(value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    context.read<ProductListProvider>().setSearch('');
  }

  Future<void> _openForm({Product? product}) async {
    final saved = await showProductFormDialog(context, product: product);
    if (!mounted || saved != true) return;
    showAppSnackBar(
      context,
      product == null ? 'Đã tạo sản phẩm mới.' : 'Đã cập nhật sản phẩm.',
      isSuccess: true,
    );
    await context.read<ProductListProvider>().refresh();
    if (mounted) context.read<DashboardProvider>().refresh();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Xóa sản phẩm?',
      message:
          'Sản phẩm "${product.name}" sẽ được chuyển sang trạng thái ngừng hoạt động. '
          'Lịch sử giao dịch vẫn được giữ lại.',
      confirmLabel: 'Xóa sản phẩm',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<ProductService>().delete(product.id);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Đã xóa sản phẩm "${product.name}".',
        isSuccess: true,
      );
      final provider = context.read<ProductListProvider>();
      if (provider.products.length == 1 && provider.page > 1) {
        await provider.setPage(provider.page - 1);
      } else {
        await provider.refresh();
      }
      if (mounted) context.read<DashboardProvider>().refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.userMessage, isError: true);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Không thể xóa sản phẩm. Vui lòng thử lại.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductListProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
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
                title: 'Sản phẩm',
                subtitle:
                    'Tìm kiếm, lọc và quản lý thông tin sản phẩm trong kho.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: provider.loading ? null : provider.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Làm mới'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm sản phẩm'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _FilterCard(
                provider: provider,
                categories: categoryProvider.categories,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onClearSearch: _clearSearch,
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: 'Danh sách sản phẩm',
                subtitle: provider.meta == null
                    ? 'Đang tải dữ liệu sản phẩm...'
                    : 'Tìm thấy ${provider.meta!.total} sản phẩm phù hợp.',
                trailing: provider.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                flush: true,
                child: _ProductResults(
                  provider: provider,
                  onOpen: (product) => context.go('/products/${product.id}'),
                  onEdit: (product) => _openForm(product: product),
                  onDelete: _deleteProduct,
                  onAdd: () => _openForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.provider,
    required this.categories,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final ProductListProvider provider;
  final List<Category> categories;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 320,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên hoặc SKU...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            onPressed: onClearSearch,
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : 210,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey(
                    'filter-category-${provider.categoryId}-${categories.length}',
                  ),
                  initialValue:
                      categories.any(
                        (category) => category.id == provider.categoryId,
                      )
                      ? provider.categoryId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tất cả danh mục'),
                    ),
                    for (final category in categories)
                      DropdownMenuItem<int?>(
                        value: category.id,
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => provider.setCategory(value),
                ),
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : 175,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(provider.sort),
                  initialValue: provider.sort,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sắp xếp'),
                  items: [
                    for (final entry
                        in _ProductListScreenState._sortOptions.entries)
                      DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) provider.setSort(value);
                  },
                ),
              ),
              Tooltip(
                message: provider.order == 'asc'
                    ? 'Đang sắp xếp tăng dần'
                    : 'Đang sắp xếp giảm dần',
                child: IconButton(
                  onPressed: () => provider.setOrder(
                    provider.order == 'asc' ? 'desc' : 'asc',
                  ),
                  icon: Icon(
                    provider.order == 'asc'
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                  ),
                ),
              ),
              if (provider.hasActiveFilters)
                TextButton.icon(
                  onPressed: () {
                    searchController.clear();
                    provider.clearFilters();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                  label: const Text('Xóa bộ lọc'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductResults extends StatelessWidget {
  const _ProductResults({
    required this.provider,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final ProductListProvider provider;
  final ValueChanged<Product> onOpen;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (provider.loading && provider.products.isEmpty) {
      return const LoadingState();
    }
    if (provider.error != null && provider.products.isEmpty) {
      return ErrorState(message: provider.error!, onRetry: provider.load);
    }
    if (provider.products.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Chưa có sản phẩm phù hợp',
        message: 'Thử thay đổi từ khóa hoặc bộ lọc, hoặc tạo sản phẩm mới để bắt đầu quản lý kho.',
        actionLabel: 'Thêm sản phẩm',
        onAction: onAdd,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.error != null)
          _InlineErrorBanner(message: provider.error!, onRetry: provider.load),
        if (provider.loading) const LinearProgressIndicator(minHeight: 2),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return ProductTable(
                products: provider.products,
                onOpen: onOpen,
                onEdit: onEdit,
                onDelete: onDelete,
              );
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < provider.products.length;
                    index++
                  ) ...[
                    ProductCard(
                      product: provider.products[index],
                      onOpen: () => onOpen(provider.products[index]),
                      onEdit: () => onEdit(provider.products[index]),
                      onDelete: () => onDelete(provider.products[index]),
                    ),
                    if (index != provider.products.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        ),
        if (provider.meta != null) ...[
          const Divider(height: 1),
          PaginationBar(
            meta: provider.meta!,
            onPageChanged: provider.setPage,
            loading: provider.loading,
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
