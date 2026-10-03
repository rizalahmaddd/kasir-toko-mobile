import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';
import '../products_providers.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(currentUserProvider)?.canManageMasterData ?? false;

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(ProductStrings.labelCategory),
        hint: ProductStrings.searchCategoryHint,
        initialSearch: ref.watch(categoriesSearchProvider),
        onSearchChanged: ref.read(categoriesSearchProvider.notifier).set,
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => FormSheet.show<void>(context, const _CategorySheet()),
              icon: const Icon(AppIcons.plus),
              label: const Text(ProductStrings.labelCategory),
            )
          : null,
      body: PagedListView(
        value: ref.watch(categoriesProvider),
        onLoadMore: () => ref.read(categoriesProvider.notifier).loadMore(),
        onRefresh: () => ref.refresh(categoriesProvider.future),
        padding: const EdgeInsets.fromLTRB(AppSpacing.s0, AppSpacing.s4, AppSpacing.s0, AppSpacing.s96),
        empty: const EmptyState(icon: AppIcons.tags, title: ProductStrings.emptyCategoriesTitle),
        itemBuilder: (context, category) => _CategoryCard(
          category: category,
          canManage: canManage,
          onTap: canManage ? () => FormSheet.show<void>(context, _CategorySheet(category: category)) : null,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.canManage, required this.onTap});

  final CategoryRecord category;
  final bool canManage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.teal700.withValues(alpha: 0.3) : AppColors.teal100,
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  child: const Icon(AppIcons.tag, size: AppSizes.s18, color: AppColors.teal600),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              category.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!category.isActive) ...[
                            const SizedBox(width: AppSizes.s6),
                            const StatusBadge(label: ProductStrings.statusInactive),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSizes.s3),
                      Text(
                        ProductStrings.categoryStatsLabel(category.productsCount ?? 0, category.sortOrder),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  const Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.category});

  final CategoryRecord? category;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _name = TextEditingController(text: widget.category?.name);
  late final _order = TextEditingController(text: '${widget.category?.sortOrder ?? 0}');
  late bool _active = widget.category?.isActive ?? true;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  void _refreshLists() => ref.read(dataChangesProvider).after({DataChange.products});

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(productsRepositoryProvider).saveCategory(
            id: widget.category?.id,
            name: _name.text.trim(),
            sortOrder: int.tryParse(_order.text) ?? 0,
            isActive: _active,
          );
      _refreshLists();
      if (mounted) {
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final category = widget.category!;
    final ok = await confirmAction(
      context,
      title: ProductStrings.categoryDeleteConfirmTitle,
      message: ProductStrings.categoryDeleteMessage(category.name),
      confirmLabel: ProductStrings.categoryDeleteConfirmAction,
      danger: true,
    );
    if (!ok) {
      return;
    }

    try {
      await ref.read(productsRepositoryProvider).deleteCategory(category.id);
      _refreshLists();
      if (mounted) {
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return FormSheet(
      title: widget.category == null ? ProductStrings.categorySheetNew : ProductStrings.categorySheetEdit,
      children: [
        TextField(
          controller: _name,
          autofocus: widget.category == null,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: ProductStrings.fieldCategoryName, errorText: _error?.fieldError('name')),
        ),
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _order,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(labelText: ProductStrings.fieldSortOrder, helperText: ProductStrings.helperSortOrder, errorText: _error?.fieldError('sort_order')),
        ),
        AppSwitchListTile(contentPadding: EdgeInsets.zero, title: const Text(ProductStrings.statusActive), value: _active, onChanged: (value) => setState(() => _active = value)),
        if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        const SizedBox(height: AppSizes.s8),
        FilledButton(onPressed: _busy ? null : _save, child: const Text(ProductStrings.labelSave)),
        if (widget.category != null)
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: StatusColors.of(context).danger),
            child: const Text(ProductStrings.actionDeleteCategory),
          ),
      ],
    );
  }
}
