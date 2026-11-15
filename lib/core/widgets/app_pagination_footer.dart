import 'package:flutter/material.dart';

import '../pagination/paginated_state.dart';
import '../theme/app_design.dart';
import 'app_button.dart';
import 'app_skeleton.dart';
import 'product_grid_skeleton.dart';

/// Returns true when the scroll position is within [threshold] pixels of the end.
bool shouldLoadNextPage(ScrollMetrics metrics, {double threshold = 280}) {
  if (metrics.maxScrollExtent <= 0) return false;
  return metrics.pixels >= metrics.maxScrollExtent - threshold;
}

/// Wraps a scrollable list or grid to automatically request the next page near bottom.
class AppPaginationScrollListener extends StatelessWidget {
  const AppPaginationScrollListener({
    super.key,
    required this.onLoadMore,
    required this.child,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.threshold = 280,
  });

  final VoidCallback onLoadMore;
  final Widget child;
  final bool hasMore;
  final bool isLoadingMore;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!hasMore || isLoadingMore) return false;
        if (notification is ScrollUpdateNotification ||
            notification is OverscrollNotification ||
            notification is ScrollEndNotification) {
          if (notification.metrics.axis == Axis.vertical &&
              shouldLoadNextPage(notification.metrics, threshold: threshold)) {
            onLoadMore();
          }
        }
        return false;
      },
      child: child,
    );
  }
}

/// Consistent bottom pagination footer supporting skeletons, retry, and load-more tap.
class AppLoadMoreFooter extends StatelessWidget {
  const AppLoadMoreFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
    required this.itemsCount,
    required this.onLoadMore,
    this.loadMoreError,
    this.useProductGridSkeleton = false,
    this.pageSize = kProductPageSize,
    this.padding,
  });

  final bool isLoadingMore;
  final bool hasMore;
  final int itemsCount;
  final VoidCallback onLoadMore;
  final Object? loadMoreError;
  final bool useProductGridSkeleton;
  final int pageSize;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (itemsCount == 0 && !hasMore && !isLoadingMore && loadMoreError == null) {
      return const SizedBox.shrink();
    }

    final resolvedPadding =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        );

    if (isLoadingMore) {
      if (useProductGridSkeleton) {
        return Padding(
          padding: resolvedPadding,
          child: Column(
            children: [
              const ProductGridSkeleton(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'جاري تحميل المزيد...'.tr,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: AppFont.medium,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: resolvedPadding,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogoMark(size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'جاري تحميل المزيد...'.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.medium,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (loadMoreError != null) {
      return Padding(
        padding: resolvedPadding,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.errorSoft,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(AppIcons.error, size: 18, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'تعذر تحميل الدفعة التالية'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.semiBold,
                    color: AppColors.text,
                  ),
                ),
              ),
              TextButton(
                onPressed: onLoadMore,
                child: Text('إعادة المحاولة'.tr),
              ),
            ],
          ),
        ),
      );
    }

    if (hasMore) {
      return Padding(
        padding: resolvedPadding,
        child: Center(
          child: AppButton(
            label: 'عرض المزيد ($pageSize منتجات)'.tr,
            variant: AppButtonVariant.outlined,
            expand: false,
            leading: Icon(AppIcons.arrowDown, size: 17),
            onPressed: onLoadMore,
          ),
        ),
      );
    }

    return Padding(
      padding: resolvedPadding,
      child: Center(
        child: Text(
          'تم عرض جميع النتائج ($itemsCount)'.tr,
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFont.medium,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Maps [PaginatedListState] to shimmer skeletons, error fallback, or content
/// using the exact same layout builder.
extension SkeletonPaginatedState<T> on PaginatedListState<T> {
  Widget skeletonWhen({
    required List<T> placeholder,
    required Widget Function(List<T> items) data,
    required Widget Function(Object error) error,
  }) {
    if (isInitialLoading && items.isEmpty) {
      return AppSkeleton(child: Builder(builder: (_) => data(placeholder)));
    }
    if (initialError != null && items.isEmpty) {
      return error(initialError!);
    }
    return data(items);
  }
}
