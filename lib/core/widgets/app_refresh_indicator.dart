import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_design.dart';
import '../utils/app_haptics.dart';

/// Branded pull-to-refresh wrapper displaying [AppLogoMark] instead of a
/// circular progress spinner.
class AppRefreshIndicator extends StatefulWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 48,
    this.edgeOffset = 0,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double displacement;
  final double edgeOffset;

  static const Duration _doubleTapWindow = Duration(milliseconds: 650);
  static final List<_AppRefreshIndicatorState> _activeInstances = [];
  static String? _lastNavRoute;
  static DateTime? _lastNavTapAt;

  /// Clears stored bottom-navigation tap state (useful in tests).
  @visibleForTesting
  static void resetNavTapTracker() {
    _lastNavRoute = null;
    _lastNavTapAt = null;
  }

  /// Triggers pull-to-refresh (scrolling to the top first if needed) on the
  /// currently visible [AppRefreshIndicator] in the active route.
  static Future<bool> refreshCurrent() async {
    final target = _findActiveInstance();
    if (target == null) return false;
    await target._scrollToTop();
    if (!target.mounted) return false;
    await target._handleRefresh();
    return true;
  }

  /// Handles bottom-navigation tab taps across all roles:
  /// - Tapping an inactive tab navigates immediately (no double-tap delay).
  /// - Tapping an already-selected tab while on a nested sub-route pops back
  ///   to [targetRoute].
  /// - Tapping the same tab twice within [_doubleTapWindow] refreshes the page
  ///   using [AppRefreshIndicator] (or falls back to scrolling to top).
  static void handleBottomNavTap({
    required String targetRoute,
    required bool selected,
    required String currentLocation,
    required VoidCallback onNavigate,
  }) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastNavRoute == targetRoute &&
        _lastNavTapAt != null &&
        now.difference(_lastNavTapAt!) <= _doubleTapWindow;

    if (isDoubleTap && selected) {
      _lastNavRoute = null;
      _lastNavTapAt = null;
      unawaited(refreshCurrent());
      return;
    }

    _lastNavRoute = targetRoute;
    _lastNavTapAt = now;

    if (!selected || currentLocation != targetRoute) {
      onNavigate();
      return;
    }

    // Single tap on the already-selected tab root: gently scroll back to top.
    final active = _findActiveInstance();
    if (active != null) {
      unawaited(active._scrollToTop());
    }
  }

  static _AppRefreshIndicatorState? _findActiveInstance() {
    _AppRefreshIndicatorState? fallback;
    for (var i = _activeInstances.length - 1; i >= 0; i--) {
      final candidate = _activeInstances[i];
      if (!candidate.mounted) continue;
      final route = ModalRoute.of(candidate.context);
      if (route?.isCurrent ?? true) {
        return candidate;
      }
      fallback ??= candidate;
    }
    return fallback;
  }

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator>
    with SingleTickerProviderStateMixin {
  static const double _maxPull = 72;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  double _pullExtent = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    AppRefreshIndicator._activeInstances.add(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    AppRefreshIndicator._activeInstances.remove(this);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _scrollToTop() async {
    if (!mounted) return;
    final scrollable = _findVerticalScrollable(context);
    if (scrollable == null || !scrollable.mounted) return;
    final position = scrollable.position;
    if (position.hasPixels && position.pixels > position.minScrollExtent) {
      await position.animateTo(
        position.minScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static ScrollableState? _findVerticalScrollable(BuildContext root) {
    ScrollableState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.position.axis == Axis.vertical) {
          found = state;
          return;
        }
      }
      element.visitChildren(visit);
    }

    root.visitChildElements(visit);
    return found;
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _pullExtent = _maxPull;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_pulseController.repeat(reverse: true));
    }
    try {
      await AppHaptics.refresh(widget.onRefresh)();
    } finally {
      _pulseController.stop();
      _pulseController.reset();
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _pullExtent = 0;
        });
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    var next = _pullExtent;
    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.dragDetails != null) {
      next = (_pullExtent - notification.overscroll * 0.55).clamp(
        0.0,
        _maxPull,
      );
    } else if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < notification.metrics.minScrollExtent &&
        notification.dragDetails != null) {
      final over =
          notification.metrics.minScrollExtent - notification.metrics.pixels;
      next = (over * 0.85).clamp(0.0, _maxPull);
    } else if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      next = 0;
    }

    if ((next - _pullExtent).abs() >= 1.5 ||
        (next == 0 && _pullExtent != 0) ||
        (next == _maxPull && _pullExtent != _maxPull)) {
      setState(() => _pullExtent = next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _isRefreshing
        ? 1.0
        : (_pullExtent / _maxPull).clamp(0.0, 1.0);
    final showBadge = _isRefreshing || progress > 0.04;

    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: _handleRefresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: widget.child,
          ),
        ),
        if (showBadge)
          Positioned(
            top: widget.edgeOffset + 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _isRefreshing ? 1.0 : progress,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _isRefreshing ? 0 : -20.0 * (1.0 - progress),
                    ),
                    child: Transform.scale(
                      scale: _isRefreshing ? 1.0 : (0.72 + 0.28 * progress),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isRefreshing
                                ? AppColors.primary
                                : AppColors.border,
                            width: _isRefreshing ? 1.5 : 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ScaleTransition(
                          scale: _isRefreshing
                              ? _pulseScale
                              : const AlwaysStoppedAnimation<double>(1.0),
                          child: const AppLogoMark(size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
