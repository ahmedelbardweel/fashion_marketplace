import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_pagination_footer.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../domain/models/catalog_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  Future<void> _openModerateSheet(AdminProduct product) async {
    final action = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: product.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.shopName ?? '-',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: AppFont.bold),
                        ),
                      ),
                      AppStatusBadge(
                        label: product.statusLabel,
                        tone: adminProductStatusTone(product.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        AppFormat.price(product.price),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: AppFont.extraBold),
                      ),
                      if (product.hasOffer &&
                          product.originalPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          AppFormat.price(product.originalPrice!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                        ),
                        const SizedBox(width: 8),
                        AppStatusBadge(
                          label: '-${product.discountPercent}%',
                          tone: BadgeTone.error,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (product.status != 'published') ...[
              AppButton(
                label: 'نشر المنتج'.tr,
                onPressed: () => Navigator.of(context).pop('published'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (product.status != 'hidden') ...[
              AppButton(
                label: 'إخفاء المنتج (مخالف)'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop('hidden'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (product.hasOffer) ...[
              AppButton(
                label: 'إلغاء العرض على المنتج'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop('cancel_offer'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.errorSoft,
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.25)),
                minimumSize: const Size(double.infinity, ButtonDesign.height),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ButtonDesign.radius),
                ),
              ),
              onPressed: AppHaptics.action(
                () => Navigator.of(context).pop('deleted'),
              ),
              child: Text('حذف المنتج نهائياً'.tr),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final actions = ref.read(adminActionProvider.notifier);
    if (action == 'cancel_offer') {
      final ok = await actions.cancelProductOffer(product.id);
      if (!mounted) return;
      showAppSnackBar(
        context,
        ok ? 'تم إلغاء العرض بنجاح'.tr : 'تعذر إلغاء العرض'.tr,
        isError: !ok,
      );
      return;
    }

    final ok = await actions.setProductStatus(
      productId: product.id,
      status: action,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تحديث المنتج'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم تحديث حالة المنتج'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminProductFilterProvider);
    final productsState = ref.watch(adminProductsPaginatedProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'جميع المنتجات'.tr,
      showBack: true,
      showBottomNav: false,
      body: productsState.skeletonWhen(
        placeholder: LoadingFixtures.adminProducts,
        error: (err) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل المنتجات',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: ref
                  .read(adminProductsPaginatedProvider.notifier)
                  .refresh,
            ),
          ],
        ),
        data: (items) {
          return Column(
            children: [
              AppFilterToolbar(
                searchValue: filter.search,
                searchHint: 'ابحث باسم المنتج أو المحل...',
                onSearchChanged: (val) =>
                    ref.read(adminProductFilterProvider.notifier).state =
                        filter.copyWith(search: val),
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'adm_prod_all',
                    label: 'الكل',
                    selected: filter.status == null,
                    onTap: () =>
                        ref.read(adminProductFilterProvider.notifier).state =
                            filter.copyWith(clearStatus: true),
                  ),
                  AppQuickFilterOption(
                    id: 'adm_prod_published',
                    label: 'منشور',
                    selected: filter.status == 'published',
                    onTap: () =>
                        ref.read(adminProductFilterProvider.notifier).state =
                            filter.copyWith(status: 'published'),
                  ),
                  AppQuickFilterOption(
                    id: 'adm_prod_hidden',
                    label: 'مخفي',
                    selected: filter.status == 'hidden',
                    onTap: () =>
                        ref.read(adminProductFilterProvider.notifier).state =
                            filter.copyWith(status: 'hidden'),
                  ),
                  AppQuickFilterOption(
                    id: 'adm_prod_draft',
                    label: 'مسودة',
                    selected: filter.status == 'draft',
                    onTap: () =>
                        ref.read(adminProductFilterProvider.notifier).state =
                            filter.copyWith(status: 'draft'),
                  ),
                ],
                totalCount: items.length,
                filteredCount: items.length,
                hasActiveCustomization: filter.hasActiveFilters,
                onClearAll: () =>
                    ref.read(adminProductFilterProvider.notifier).state =
                        AdminProductFilterState.empty,
                showCountWhenUnfiltered: true,
              ),
              Expanded(
                child: items.isEmpty && !productsState.isInitialLoading
                    ? AdminCenteredEmptyView(
                        onRefresh: ref
                            .read(adminProductsPaginatedProvider.notifier)
                            .refresh,
                        title: 'لا توجد منتجات مطابقة',
                        message: 'جرّب تعديل الفلاتر أو البحث بكلمة أخرى.',
                      )
                    : AppRefreshIndicator(
                        onRefresh: ref
                            .read(adminProductsPaginatedProvider.notifier)
                            .refresh,
                        child: AppPaginationScrollListener(
                          hasMore: productsState.hasMore,
                          isLoadingMore: productsState.isLoadingMore,
                          onLoadMore: ref
                              .read(adminProductsPaginatedProvider.notifier)
                              .loadMore,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppSpacing.page,
                            itemCount: items.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              if (index == items.length) {
                                return AppLoadMoreFooter(
                                  isLoadingMore: productsState.isLoadingMore,
                                  hasMore: productsState.hasMore,
                                  itemsCount: items.length,
                                  loadMoreError: productsState.loadMoreError,
                                  onLoadMore: ref
                                      .read(
                                        adminProductsPaginatedProvider.notifier,
                                      )
                                      .loadMore,
                                );
                              }
                              final product = items[index];
                              final subtitle = [
                                if (product.shopName != null) product.shopName!,
                                if (product.shopCity?.isNotEmpty ?? false)
                                  product.shopCity!,
                                if (product.categoryName != null)
                                  product.categoryName!,
                              ].join(' · ');

                              return Material(
                                color: SellerDesign.statCardBackground,
                                borderRadius: BorderRadius.circular(
                                  CardDesign.radius,
                                ),
                                child: InkWell(
                                  onTap: busy
                                      ? null
                                      : AppHaptics.action(
                                          () => _openModerateSheet(product),
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    CardDesign.radius,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        CardDesign.radius,
                                      ),
                                      border: Border.all(
                                        color: SellerDesign.statCardBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (product.coverImage != null &&
                                            product.coverImage!.isNotEmpty) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              AppRadii.sm,
                                            ),
                                            child: AppNetworkImage(
                                              product.coverImage!,
                                              width: 54,
                                              height: 54,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const SizedBox.shrink(),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight: AppFont.bold,
                                                    ),
                                              ),
                                              if (subtitle.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    AppFormat.price(
                                                      product.price,
                                                    ),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              AppFont.extraBold,
                                                          color: AppColors.text,
                                                        ),
                                                  ),
                                                  if (product.hasOffer) ...[
                                                    const SizedBox(width: 6),
                                                    AppStatusBadge(
                                                      label:
                                                          '-${product.discountPercent}%',
                                                      tone: BadgeTone.error,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        AppStatusBadge(
                                          label: product.statusLabel,
                                          tone: adminProductStatusTone(
                                            product.status,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
