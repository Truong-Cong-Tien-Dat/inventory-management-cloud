import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/global_refresh_mixin.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_card.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with GlobalRefreshMixin<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CategoryProvider>().load(force: true);
    });
  }

  @override
  Future<void> onGlobalRefresh() {
    return context.read<CategoryProvider>().load(force: true);
  }

  Future<void> _addCategory() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AddCategoryDialog(),
    );
    if (!mounted || created != true) return;
    showAppSnackBar(context, 'Đã thêm danh mục mới.', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final compact = MediaQuery.sizeOf(context).width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Danh mục',
                subtitle: 'Quản lý nhóm sản phẩm và xem số lượng sản phẩm đang hoạt động.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: provider.loading
                        ? null
                        : () => provider.load(force: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Làm mới'),
                  ),
                  FilledButton.icon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm danh mục'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (provider.loading && provider.categories.isEmpty)
                const SectionCard(
                  child: LoadingState(message: 'Đang tải danh mục...'),
                )
              else if (provider.error != null && provider.categories.isEmpty)
                SectionCard(
                  child: ErrorState(
                    message: provider.error!,
                    onRetry: () => provider.load(force: true),
                  ),
                )
              else if (provider.categories.isEmpty)
                SectionCard(
                  child: EmptyState(
                    icon: Icons.category_outlined,
                    title: 'Chưa có danh mục',
                    message:
                        'Tạo danh mục đầu tiên để nhóm các sản phẩm trong kho.',
                    actionLabel: 'Thêm danh mục',
                    onAction: _addCategory,
                  ),
                )
              else ...[
                if (provider.loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (provider.error != null) ...[
                  _InlineErrorBanner(
                    message: provider.error!,
                    onRetry: () => provider.load(force: true),
                  ),
                  const SizedBox(height: 14),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 1100
                        ? 3
                        : width >= 700
                        ? 2
                        : 1;
                    const spacing = 16.0;
                    final cardWidth =
                        (width - spacing * (columns - 1)) / columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final category in provider.categories)
                          SizedBox(
                            width: cardWidth,
                            child: _CategoryCard(category: category),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/products?categoryId=${category.id}'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 14,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${AppFormatters.number(category.productCount)} sản phẩm đang hoạt động',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tạo ngày ${AppFormatters.date(category.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _submitting = false;
  String? _nameError;
  String? _serverError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _nameError = null;
      _serverError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await context.read<CategoryProvider>().create(_nameController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == 'CATEGORY_EXISTS') {
          _nameError = error.userMessage;
        } else {
          _serverError = error.userMessage;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _serverError = 'Không thể tạo danh mục. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.category_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thêm danh mục',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Tạo nhóm sản phẩm mới trong kho.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  enabled: !_submitting,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                  validator: (value) =>
                      _nameError ?? AppValidators.categoryName(value),
                  decoration: const InputDecoration(
                    labelText: 'Tên danh mục *',
                    hintText: 'Ví dụ: Đồ gia dụng',
                  ),
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _serverError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tạo danh mục'),
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
