import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/app_design.dart';

/// Skeletons reuse the real page builder; placeholders never enter providers.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => !enabled
      ? child
      : Semantics(
          label: 'جارٍ التحميل',
          child: ExcludeSemantics(
            child: ExcludeFocus(
              child: Skeletonizer(
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
        );
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
    data: data,
    error: error,
    loading: () =>
        AppSkeleton(child: Builder(builder: (_) => data(placeholder))),
  );
}

/// Keeps the real image bounds while loading, without fetching placeholder URLs.
class AppNetworkImage extends StatelessWidget {
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
  });
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final int? cacheWidth, cacheHeight;
  final Color? color;
  final BlendMode? colorBlendMode;
  final AlignmentGeometry alignment;

  Widget _bone() => Bone(width: width, height: height);
  @override
  Widget build(BuildContext context) {
    if (Skeletonizer.maybeOf(context)?.enabled ?? false) return _bone();
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      errorBuilder: errorBuilder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : AppSkeleton(child: _bone()),
    );
  }
}

/// Busy actions retain their label and size instead of becoming a spinner.
class AppBusyLabel extends StatelessWidget {
  const AppBusyLabel({super.key, this.label = 'جارٍ التنفيذ…'});
  final String label;
  @override
  Widget build(BuildContext context) => AppSkeleton(child: Text(label));
}
