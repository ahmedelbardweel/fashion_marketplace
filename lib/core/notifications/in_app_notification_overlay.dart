import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../utils/app_haptics.dart';
import 'notification_models.dart';
import 'push_notification_service.dart';

/// Displays sleek, interactive floating notification banners at the top of the
/// viewport whenever a push or realtime notification arrives in the foreground.
class InAppNotificationOverlay extends StatefulWidget {
  const InAppNotificationOverlay({
    super.key,
    required this.child,
    required this.onNotificationTap,
  });

  final Widget child;
  final void Function(Map<String, dynamic> data) onNotificationTap;

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  StreamSubscription<InAppNotificationAlert>? _sub;
  InAppNotificationAlert? _activeAlert;
  bool _visible = false;
  Timer? _dismissTimer;
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _sub = PushNotificationService.instance.onInAppAlert.listen(_showAlert);
  }

  void _showAlert(InAppNotificationAlert alert) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    _clearTimer?.cancel();
    AppHaptics.selection();
    setState(() {
      _activeAlert = alert;
      _visible = true;
    });
    _dismissTimer = Timer(const Duration(seconds: 5), _hideAlert);
  }

  void _hideAlert() {
    _dismissTimer?.cancel();
    if (!mounted || !_visible) return;
    setState(() => _visible = false);
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted && !_visible) {
        setState(() => _activeAlert = null);
      }
    });
  }

  void _onTapActive() {
    final alert = _activeAlert;
    _hideAlert();
    if (alert != null) {
      widget.onNotificationTap(alert.data);
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _clearTimer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alert = _activeAlert;
    return Stack(
      children: [
        widget.child,
        if (alert != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  offset: _visible ? Offset.zero : const Offset(0, -1.3),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _visible ? 1.0 : 0.0,
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) < -120) {
                          _hideAlert();
                        }
                      },
                      onTap: _onTapActive,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.isDark
                                ? const Color(0xFF1A1B1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: alert.category.accentColor.withValues(
                                alpha: 0.35,
                              ),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _BannerLeading(alert: alert),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            alert.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: AppFont.bold,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: alert.category.accentColor
                                                .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              AppRadii.pill,
                                            ),
                                          ),
                                          child: Text(
                                            alert.category.shortLabel.tr,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: AppFont.bold,
                                              color: alert.category.accentColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (alert.body.trim().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        alert.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _hideAlert,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _BannerLeading extends StatelessWidget {
  const _BannerLeading({required this.alert});

  final InAppNotificationAlert alert;

  @override
  Widget build(BuildContext context) {
    final imageUrl = alert.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          imageUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _iconBox(),
        ),
      );
    }
    return _iconBox();
  }

  Widget _iconBox() {
    final accent = alert.category.accentColor;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(alert.category.icon, color: accent, size: 21),
    );
  }
}
