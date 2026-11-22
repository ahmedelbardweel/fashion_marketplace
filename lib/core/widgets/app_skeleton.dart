import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../offline/offline_image_cache_service.dart';
import '../theme/app_design.dart';

export 'package:skeletonizer/skeletonizer.dart' show Bone;

/// Skeletons reuse the real page builder; placeholders never enter providers.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  static bool isActive(BuildContext context) =>
      Skeletonizer.maybeOf(context)?.enabled ?? false;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Semantics(
      label: enabled ? 'جارٍ التحميل'.tr : null,
      child: ExcludeSemantics(
        excluding: enabled,
        child: ExcludeFocus(
          excluding: enabled,
          child: Theme(
            data: enabled
                ? baseTheme.copyWith(
                    switchTheme: SwitchThemeData(
                      thumbColor: WidgetStatePropertyAll(
                        SkeletonDesign.highlight,
                      ),
                      trackColor: WidgetStatePropertyAll(SkeletonDesign.base),
                      trackOutlineColor: WidgetStatePropertyAll(
                        AppColors.border,
                      ),
                    ),
                  )
                : baseTheme,
            child: Skeletonizer(
              enabled: enabled,
              effect: ShimmerEffect(
                baseColor: SkeletonDesign.base,
                highlightColor: SkeletonDesign.highlight,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : SkeletonDesign.duration,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

extension SkeletonAsyncValue<T> on AsyncValue<T> {
  Widget skeletonWhen({
    required T placeholder,
    required Widget Function(T) data,
    required Widget Function(Object, StackTrace) error,
    bool skipLoadingOnReload = true,
    bool skipLoadingOnRefresh = true,
  }) => when(
    skipLoadingOnReload: skipLoadingOnReload,
    skipLoadingOnRefresh: skipLoadingOnRefresh,
    data: (value) => AppSkeleton(
      enabled: false,
      child: Builder(builder: (_) => data(value)),
    ),
    error: error,
    loading: () => AppSkeleton(
      enabled: true,
      child: Builder(builder: (_) => data(placeholder)),
    ),
  );
}

/// Offline-capable network image widget with persistent disk caching and
/// automatic skeleton placeholder while loading.
class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.contentPadding = EdgeInsets.zero,
  });
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final int? cacheWidth, cacheHeight;
  final Color? color;
  final BlendMode? colorBlendMode;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  File? _cachedFile;
  bool _resolvingDisk = false;

  @override
  void initState() {
    super.initState();
    _resolveFromCacheOrDownload();
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _cachedFile = null;
      _resolvingDisk = false;
      _resolveFromCacheOrDownload();
    }
  }

  void _resolveFromCacheOrDownload() {
    if (kIsWeb || widget.url.trim().isEmpty) return;

    final syncFile = OfflineImageCacheService.instance.getCachedFileSync(
      widget.url,
    );
    if (syncFile != null) {
      _cachedFile = syncFile;
      return;
    }

    if (!OfflineImageCacheService.instance.isReady) {
      return;
    }

    _resolvingDisk = true;
    final targetUrl = widget.url;
    OfflineImageCacheService.instance.getOrDownloadFile(targetUrl).then((file) {
      if (!mounted || widget.url != targetUrl) return;
      setState(() {
        _cachedFile = file;
        _resolvingDisk = false;
      });
    });
  }

  Widget _bone() => Bone(width: widget.width, height: widget.height);

  Widget _wrapPadding(Widget child) {
    if (widget.contentPadding == EdgeInsets.zero) return child;
    return Padding(padding: widget.contentPadding, child: child);
  }

  Widget _buildError(BuildContext context, Object error, StackTrace? stack) {
    if (widget.errorBuilder != null) {
      return _wrapPadding(widget.errorBuilder!(context, error, stack));
    }
    return _wrapPadding(
      SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Skeletonizer.maybeOf(context)?.enabled ?? false) return _bone();

    final file =
        _cachedFile ??
        OfflineImageCacheService.instance.getCachedFileSync(widget.url);

    if (file != null) {
      return _wrapPadding(
        Image.file(
          file,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          color: widget.color,
          colorBlendMode: widget.colorBlendMode,
          alignment: widget.alignment,
          errorBuilder: _buildError,
        ),
      );
    }

    if (_resolvingDisk) {
      return AppSkeleton(child: _bone());
    }

    // Fallback when disk cache service is not initialized (e.g. Web or unit tests)
    // or if disk download failed while online.
    return Image.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      alignment: widget.alignment,
      errorBuilder: widget.errorBuilder == null ? null : _buildError,
      loadingBuilder: (context, child, progress) {
        if (progress != null) return AppSkeleton(child: _bone());
        return _wrapPadding(child);
      },
    );
  }
}

/// Busy actions retain their label and size instead of becoming a spinner.
class AppBusyLabel extends StatelessWidget {
  const AppBusyLabel({super.key, this.label = 'جارٍ التنفيذ…'});
  final String label;
  @override
  Widget build(BuildContext context) => AppSkeleton(child: Text(label.tr));
}
