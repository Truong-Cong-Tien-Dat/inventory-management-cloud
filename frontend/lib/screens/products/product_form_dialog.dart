import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/product_input.dart';
import '../../providers/category_provider.dart';
import '../../services/product_service.dart';

Future<bool?> showProductFormDialog(BuildContext context, {Product? product}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ProductFormDialog(product: product),
  );
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _reorderController;
  late final TextEditingController _descriptionController;

  int? _categoryId;
  bool _submitting = false;
  String? _serverError;
  String? _skuError;
  String? _categoryError;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _skuController = TextEditingController(text: product?.sku ?? '');
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : AppFormatters.inputNumber(product.unitPrice),
    );
    _reorderController = TextEditingController(
      text: product?.reorderLevel.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _categoryId = product?.categoryId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CategoryProvider>();
      if (provider.categories.isEmpty) provider.load();
    });
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _reorderController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _serverError = null;
      _skuError = null;
      _categoryError = null;
    });

    final formValid = _formKey.currentState?.validate() ?? false;
    if (_categoryId == null) {
      setState(() => _categoryError = 'Vui lòng chọn danh mục.');
      return;
    }
    if (!formValid) return;

    setState(() => _submitting = true);

    final input = ProductInput(
      sku: _skuController.text,
      name: _nameController.text,
      categoryId: _categoryId!,
      description: _descriptionController.text,
      unitPrice: double.parse(_priceController.text.trim()),
      reorderLevel: int.parse(_reorderController.text.trim()),
    );

    try {
      final service = context.read<ProductService>();
      if (_isEditing) {
        await service.update(widget.product!.id, input);
      } else {
        await service.create(input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == 'DUPLICATE_SKU') {
          _skuError = error.userMessage;
        } else if (error.code == 'CATEGORY_NOT_FOUND') {
          _categoryError = error.userMessage;
        } else {
          _skuError = error.fieldError('sku');
          _categoryError = error.fieldError('categoryId');
          _serverError = error.userMessage;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _serverError = 'Không thể lưu sản phẩm. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.categories;
    final noCategories = !categoryProvider.loading && categories.isEmpty;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: EdgeInsets.all(size.width < 700 ? 12 : 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isEditing
                                ? 'Cập nhật thông tin sản phẩm. Tồn kho chỉ thay đổi qua giao dịch kho.'
                                : 'Tạo sản phẩm mới. Tồn kho ban đầu luôn là 0.',
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
                if (categoryProvider.loading && categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (noCategories) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Chưa có danh mục. Vui lòng tạo danh mục trước khi thêm sản phẩm.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                            context.go('/categories');
                          },
                          child: const Text('Tạo danh mục'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 560;
                    final skuField = TextFormField(
                      controller: _skuController,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) {
                        if (_skuError != null) setState(() => _skuError = null);
                      },
                      validator: (value) =>
                          _skuError ?? AppValidators.sku(value),
                      decoration: const InputDecoration(
                        labelText: 'Mã SKU *',
                        hintText: 'VD: SP-001',
                      ),
                    );
                    final nameField = TextFormField(
                      controller: _nameController,
                      enabled: !_submitting,
                      validator: AppValidators.name,
                      decoration: const InputDecoration(
                        labelText: 'Tên sản phẩm *',
                        hintText: 'VD: Áo thun cotton',
                      ),
                    );

                    return Column(
                      children: [
                        if (twoColumns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: skuField),
                              const SizedBox(width: 14),
                              Expanded(child: nameField),
                            ],
                          )
                        else ...[
                          skuField,
                          const SizedBox(height: 14),
                          nameField,
                        ],
                        const SizedBox(height: 14),
                        if (twoColumns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _categoryField(categories)),
                              const SizedBox(width: 14),
                              Expanded(child: _reorderField()),
                            ],
                          )
                        else ...[
                          _categoryField(categories),
                          const SizedBox(height: 14),
                          _reorderField(),
                        ],
                        const SizedBox(height: 14),
                        if (twoColumns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _priceField()),
                              const SizedBox(width: 14),
                              const Expanded(child: SizedBox()),
                            ],
                          )
                        else
                          _priceField(),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_submitting,
                          maxLines: 4,
                          maxLength: 2000,
                          validator: AppValidators.description,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả',
                            hintText:
                                'Thông tin thêm về sản phẩm (không bắt buộc)',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (_serverError != null) ...[
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
                            _serverError!,
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
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _submitting || noCategories ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_isEditing ? 'Lưu thay đổi' : 'Tạo sản phẩm'),
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

  Widget _categoryField(List<Category> categories) {
    final hasSelectedCategory = categories.any(
      (category) => category.id == _categoryId,
    );
    return DropdownButtonFormField<int>(
      key: ValueKey('category-${categories.length}-${_categoryId ?? 'none'}'),
      initialValue: hasSelectedCategory ? _categoryId : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Danh mục *',
        errorText: _categoryError,
      ),
      items: [
        for (final category in categories)
          DropdownMenuItem<int>(
            value: category.id,
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _submitting
          ? null
          : (value) {
              setState(() {
                _categoryId = value;
                _categoryError = null;
              });
            },
      validator: (value) => value == null ? 'Vui lòng chọn danh mục.' : null,
    );
  }

  Widget _reorderField() {
    return TextFormField(
      controller: _reorderController,
      enabled: !_submitting,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: AppValidators.reorderLevel,
      decoration: const InputDecoration(
        labelText: 'Mức tồn kho tối thiểu *',
        hintText: 'VD: 10',
      ),
    );
  }

  Widget _priceField() {
    return TextFormField(
      controller: _priceController,
      enabled: !_submitting,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: AppValidators.unitPrice,
      decoration: const InputDecoration(
        labelText: 'Đơn giá (VND) *',
        hintText: 'VD: 250000',
      ),
    );
  }
}
