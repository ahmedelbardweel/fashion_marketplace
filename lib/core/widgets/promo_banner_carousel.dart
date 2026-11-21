import 'dart:async';

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';

import '../../features/admin/domain/models/catalog_models.dart';
import '../theme/app_design.dart';
import 'app_skeleton.dart';

/// Full-width promotional banner carousel shared between Customer Home and
/// Shop Dashboard live preview so shop owners see the exact customer appearance.
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({
    super.key,
    required this.banners,
    required this.onBannerTap,
  });

  final List<AdminBanner> banners;
  final ValueChanged<AdminBanner> onBannerTap;

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final PageController _controller = PageController();
  Timer? _autoPlayTimer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant PromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      if (widget.banners.isNotEmpty && _index >= widget.banners.length) {
        _index = widget.banners.length - 1;
      } else if (widget.banners.isEmpty) {
        _index = 0;
      }
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length <= 1) return;
    _autoPlayTimer = Timer.periodic(HomeDesign.bannerAutoPlay, (_) {
      if (!mounted || !_controller.hasClients || widget.banners.isEmpty) return;
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
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: HomeDesign.bannerHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final isSkeleton = AppSkeleton.isActive(context);
              final b = widget.banners[index];
              final hasImage =
                  !isSkeleton &&
                  b.imagePath != null &&
                  b.imagePath!.trim().isNotEmpty;
              return Material(
                color: isSkeleton
                    ? SkeletonDesign.base
                    : HomeDesign.bannerBackground,
                borderRadius: BorderRadius.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: AppHaptics.action(() => widget.onBannerTap(b)),
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
                              colors: [Color(0xB8000000), Color(0x4D000000)],
                            ),
                          ),
                        ),
                      ] else if (!isSkeleton) ...[
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
                          horizontal: AppSpacing.lg,
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
                                      color: isSkeleton
                                          ? SkeletonDesign.highlight
                                          : AppPalette.white.withValues(
                                              alpha: 0.18,
                                            ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                    child: Text(
                                      (b.isShopBanner && b.isAutoOffer
                                              ? 'عروض المحل'
                                              : 'عرض خاص')
                                          .tr,
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
                                color: isSkeleton
                                    ? SkeletonDesign.highlight
                                    : HomeDesign.bannerButtonBackground,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (b.ctaLabel != null &&
                                                b.ctaLabel!.trim().isNotEmpty
                                            ? b.ctaLabel!.trim()
                                            : (b.isShopBanner
                                                  ? 'تصفح المحل'
                                                  : 'تسوق الآن'))
                                        .tr,
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
