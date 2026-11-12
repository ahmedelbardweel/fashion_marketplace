import 'dart:async';

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';
import '../widgets/product_cart_sheet.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  Future<void> _toggleFavorite(WidgetRef ref, String productId) async {
    await ref.read(customerRepositoryProvider).toggleFavorite(productId);
    ref.invalidate(customerProductsProvider);
    ref.invalidate(customerFavoritesProvider);
    ref.invalidate(customerProductDetailsProvider(productId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(customerBannersProvider);
    final categoriesAsync = ref.watch(customerCategoriesProvider);
    final shopsAsync = ref.watch(customerShopsProvider);
    final productsAsync = ref.watch(customerProductsProvider);

    return CustomerScaffold(
      title: 'السوق العصري'.tr,
      currentNavIndex: 0,
      showBack: false,
      showProfile: true,
      body: RefreshIndicator.noSpinner(
        onRefresh: AppHaptics.refresh(() async {
          ref.invalidate(customerBannersProvider);
          ref.invalidate(customerCategoriesProvider);
          ref.invalidate(customerShopsProvider);
          ref.invalidate(customerProductsProvider);
        }),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) Promotional Hero Banners
              bannersAsync.skeletonWhen(
                placeholder: LoadingFixtures.banners,
                data: (banners) {
                  if (banners.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _HomeBannerCarousel(banners: banners),
                  );
                },
                error: (_, _) => const SizedBox.shrink(),
              ),

              // 2) Categories Pills
              categoriesAsync.skeletonWhen(
                placeholder: LoadingFixtures.categories,
                data: (categories) {
                  if (categories.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: SectionDesign.spacingBetweenSections,
                    ),
                    child: SizedBox(
                      height: HomeDesign.categoryHeight,
                      child: ListView.separated(
                        padding: AppSpacing.pageHorizontal,
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return InkWell(
                            onTap: AppHaptics.action(() {
                              ref.read(productFilterProvider.notifier).state =
                                  ProductFilter(categoryId: cat.id);
                              context.push(AppRoutes.customerCatalog);
                            }),
                            borderRadius: BorderRadius.circular(
                              ChipDesign.radius,
                            ),
                            child: Container(
                              padding: ChipDesign.padding,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: ChipDesign.background,
                                borderRadius: BorderRadius.circular(
                                  ChipDesign.radius,
                                ),
                                border: Border.all(color: ChipDesign.border),
                              ),
                              child: Text(
                                cat.name.tr,
                                style: TextStyle(
                                  fontSize: ChipDesign.textSize,
                                  fontWeight: ChipDesign.textWeight,
                                  color: ChipDesign.text,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                error: (_, _) => const SizedBox.shrink(),
              ),

              // 3) Approved Shops (Story-style Avatars)
              AppSectionHeader(
                title: 'المتاجر المعتمدة'.tr,
                actionLabel: 'عرض الكل'.tr,
                onAction: AppHaptics.action(
                  () => context.push(AppRoutes.customerShops),
                ),
              ),
              const SizedBox(height: SectionDesign.spacingBelow),
              shopsAsync.skeletonWhen(
                placeholder: LoadingFixtures.customerShops,
                data: (shops) {
                  if (shops.isEmpty) {
                    return Padding(
                      padding: AppSpacing.pageHorizontal,
                      child: Text(
                        'لا توجد محلات معتمدة حالياً'.tr,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return SizedBox(
                    height: HomeDesign.shopAvatarSize + 26,
                    child: ListView.separated(
                      padding: AppSpacing.pageHorizontal,
                      scrollDirection: Axis.horizontal,
                      itemCount: shops.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final shop = shops[index];
                        return InkWell(
                          onTap: AppHaptics.action(
                            () => context.push(
                              AppRoutes.customerShopProfilePath(shop.id),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          child: SizedBox(
                            width: HomeDesign.shopItemWidth,
                            child: Column(
                              children: [
                                Container(
                                  width: HomeDesign.shopAvatarSize,
                                  height: HomeDesign.shopAvatarSize,
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: HomeDesign.shopAvatarBorder,
                                      width: HomeDesign.shopAvatarBorderWidth,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: ColoredBox(
                                      color: HomeDesign.shopAvatarBackground,
                                      child:
                                          shop.logoPath != null &&
                                              shop.logoPath!.isNotEmpty
                                          ? AppNetworkImage(
                                              shop.logoPath!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  Icon(
                                                    AppIcons.shopActive,
                                                    color: HomeDesign
                                                        .shopAvatarIcon,
                                                  ),
                                            )
                                          : Icon(
                                              AppIcons.shopActive,
                                              color: HomeDesign.shopAvatarIcon,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    shop.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: HomeDesign.shopNameSize,
                                      fontWeight: HomeDesign.shopNameWeight,
                                      color: AppColors.text,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: SectionDesign.spacingBetweenSections),

              // 4) Latest Products Grid
              AppSectionHeader(
                title: 'أحدث الأزياء'.tr,
                actionLabel: 'تصفح الكل'.tr,
                onAction: AppHaptics.action(
                  () => context.push(AppRoutes.customerCatalog),
                ),
              ),
              const SizedBox(height: SectionDesign.spacingBelow),

              productsAsync.skeletonWhen(
                placeholder: LoadingFixtures.products,
                data: (products) {
                  if (products.isEmpty) {
                    return AppEmpty(
                      icon: AppIcons.garment,
                      message: 'لا توجد منتجات منشورة حالياً'.tr,
                    );
                  }
                  return Padding(
                    padding: AppSpacing.pageHorizontal,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate: ProductGridDelegate(
                        textScale:
                            MediaQuery.textScalerOf(context).scale(14) / 14,
                      ),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductGridCard(
                          imageUrl: product.coverImage,
                          meta: AppFormat.price(product.price),
                          inStock: product.totalStock > 0,
                          isFavorite: product.isFavorite,
                          onToggleFavorite: () =>
                              _toggleFavorite(ref, product.id),
                          onAddToCart: () =>
                              showProductCartSheet(context, product.id),
                          onTap: () => context.push(
                            AppRoutes.customerProductDetailsPath(product.id),
                          ),
                        );
                      },
                    ),
                  );
                },
                error: (err, _) => AppEmpty(
                  icon: AppIcons.error,
                  message: 'تعذر تحميل المنتجات: $err'.tr,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBannerCarousel extends StatefulWidget {
  const _HomeBannerCarousel({required this.banners});

  final List<AdminBanner> banners;

  @override
  State<_HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<_HomeBannerCarousel> {
  final PageController _controller = PageController();
  Timer? _autoPlayTimer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length <= 1) return;
    _autoPlayTimer = Timer.periodic(HomeDesign.bannerAutoPlay, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: AppMotion.normal,
        curve: AppMotion.curve,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: HomeDesign.bannerHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final b = widget.banners[index];
              final hasImage =
                  b.imagePath != null && b.imagePath!.trim().isNotEmpty;
              const bannerShape = _TaperedBannerBorder(
                radius: HomeDesign.bannerRadius,
                bottomInset: HomeDesign.bannerBottomInset,
              );
              return Padding(
                padding: AppSpacing.pageHorizontal,
                child: Material(
                  color: HomeDesign.bannerBackground,
                  shape: bannerShape,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: AppHaptics.action(
                      () => context.push(AppRoutes.customerCatalog),
                    ),
                    customBorder: bannerShape,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage) ...[
                          AppNetworkImage(
                            b.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [
                                  Color(0xB8000000),
                                  Color(0x4D000000),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          PositionedDirectional(
                            end: -28,
                            top: -28,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppPalette.white.withValues(alpha: 0.10),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            end: 40,
                            bottom: -40,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppPalette.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                AppSpacing.lg + HomeDesign.bannerBottomInset,
                            vertical: AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.white.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                      ),
                                      child: Text(
                                        'عرض خاص'.tr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: AppFont.bold,
                                          color: HomeDesign.bannerTitle,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        b.title.tr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: HomeDesign.bannerTitleSize,
                                          fontWeight:
                                              HomeDesign.bannerTitleWeight,
                                          color: HomeDesign.bannerTitle,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    if (b.subtitle != null &&
                                        b.subtitle!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Flexible(
                                        child: Text(
                                          b.subtitle!.tr,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: AppFont.medium,
                                            color: HomeDesign.bannerSubtitle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: HomeDesign.bannerButtonBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'تسوق الآن'.tr,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: AppFont.bold,
                                        color: HomeDesign.bannerButtonText,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      AppIcons.arrowForward,
                                      size: 14,
                                      color: HomeDesign.bannerButtonText,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _index;
              return GestureDetector(
                onTap: () => _controller.animateToPage(
                  i,
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                ),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  width: active ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: active
                        ? HomeDesign.bannerDotActive
                        : HomeDesign.bannerDotInactive,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// شكل بطاقة البانر: عرض أوسع من الأعلى ويضيق تدريجياً نحو الأسفل مع زوايا دائرية ناعمة.
class _TaperedBannerBorder extends OutlinedBorder {
  const _TaperedBannerBorder({
    this.radius = 18,
    this.bottomInset = 18,
    super.side,
  });

  final double radius;
  final double bottomInset;

  @override
  OutlinedBorder copyWith({
    BorderSide? side,
    double? radius,
    double? bottomInset,
  }) {
    return _TaperedBannerBorder(
      side: side ?? this.side,
      radius: radius ?? this.radius,
      bottomInset: bottomInset ?? this.bottomInset,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _buildPath(rect.deflate(side.strokeInset));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _buildPath(rect);
  }

  Path _buildPath(Rect rect) {
    final inset = bottomInset.clamp(0.0, rect.width * 0.25);
    final r = radius.clamp(0.0, rect.height * 0.35);

    final tl = Offset(rect.left, rect.top);
    final tr = Offset(rect.right, rect.top);
    final br = Offset(rect.right - inset, rect.bottom);
    final bl = Offset(rect.left + inset, rect.bottom);

    final vertices = [tl, tr, br, bl];
    final path = Path();

    for (var i = 0; i < vertices.length; i++) {
      final prev = vertices[(i - 1 + vertices.length) % vertices.length];
      final curr = vertices[i];
      final next = vertices[(i + 1) % vertices.length];

      final toPrev = prev - curr;
      final toNext = next - curr;
      final prevLen = toPrev.distance;
      final nextLen = toNext.distance;

      final minSide = prevLen < nextLen ? prevLen : nextLen;
      final cornerOffset = r.clamp(0.0, minSide * 0.45);
      final pStart = curr + (toPrev / prevLen) * cornerOffset;
      final pEnd = curr + (toNext / nextLen) * cornerOffset;

      if (i == 0) {
        path.moveTo(pStart.dx, pStart.dy);
      } else {
        path.lineTo(pStart.dx, pStart.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, pEnd.dx, pEnd.dy);
    }

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    canvas.drawPath(getOuterPath(rect), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) {
    return _TaperedBannerBorder(
      side: side.scale(t),
      radius: radius * t,
      bottomInset: bottomInset * t,
    );
  }
}
