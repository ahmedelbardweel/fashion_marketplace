import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import 'app_skeleton.dart';

/// Opens a clean full-screen zoomable viewer for uploaded transfer receipts.
Future<void> showReceiptImageViewer(
  BuildContext context, {
  required String imageUrl,
  String? title,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    builder: (ctx) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.5,
                  child: Center(
                    child: AppNetworkImage(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.addPhoto,
                            size: 48,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'تعذر تحميل صورة الإشعار'.tr,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Row(
                  children: [
                    if (title != null && title.trim().isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: AppFont.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: AppSpacing.sm),
                    Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
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
  );
}

/// Compact clickable preview card for an uploaded payment transfer receipt.
class ReceiptThumbnailCard extends StatelessWidget {
  const ReceiptThumbnailCard({
    super.key,
    required this.imageUrl,
    this.subtitle,
    this.height = 148,
  });

  final String imageUrl;
  final String? subtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showReceiptImageViewer(
        context,
        imageUrl: imageUrl,
        title: subtitle ?? 'إشعار الحوالة المالية'.tr,
      ),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  AppIcons.addPhoto,
                  color: AppColors.textMuted,
                  size: 36,
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_in_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'عرض الإشعار بالحجم الكامل'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: AppFont.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
