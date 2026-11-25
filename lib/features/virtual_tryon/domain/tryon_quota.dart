import 'tryon_provider.dart';

export 'tryon_provider.dart';

enum TryonBlockReason {
  disabledByAdmin,
  tokensDepleted,
  dailyLimitReached,
}

class TryonQuota {
  const TryonQuota({
    this.enabled = true,
    this.tokensAvailable = true,
    this.activeProvider = TryonProvider.decart,
    this.sessionDurationSeconds = 30,
    this.dailyLimit = 3,
    this.usedToday = 0,
    this.remainingToday = 3,
    this.blockReasonOverride,
  });

  final bool enabled;
  final bool tokensAvailable;
  final TryonProvider activeProvider;
  final int sessionDurationSeconds;
  final int dailyLimit;
  final int usedToday;
  final int remainingToday;
  final TryonBlockReason? blockReasonOverride;

  TryonBlockReason? get blockReason {
    if (blockReasonOverride != null) return blockReasonOverride;
    if (!enabled) return TryonBlockReason.disabledByAdmin;
    if (!tokensAvailable) return TryonBlockReason.tokensDepleted;
    if (remainingToday <= 0) return TryonBlockReason.dailyLimitReached;
    return null;
  }

  bool get isBlocked => blockReason != null;

  bool get hasRemaining => !isBlocked;

  String? get friendlyBlockedTitle {
    return switch (blockReason) {
      TryonBlockReason.dailyLimitReached => 'انتهت محاولاتك اليومية',
      TryonBlockReason.tokensDepleted => 'التجربة متوقفة مؤقتاً',
      TryonBlockReason.disabledByAdmin => 'التجربة متوقفة مؤقتاً',
      null => null,
    };
  }

  String? get friendlyBlockedMessage {
    return switch (blockReason) {
      TryonBlockReason.dailyLimitReached =>
        'استهلكت جميع محاولاتك اليومية لتجربة الملابس ($dailyLimit محاولات). ستعود محاولاتك تلقائياً غداً!',
      TryonBlockReason.tokensDepleted =>
        'خدمة تجربة الملابس الافتراضية متوقفة مؤقتاً لنفاد رصيد التجربة في التطبيق، وسيتم تفعيلها مجدداً فور تجديده من قبل الإدارة.',
      TryonBlockReason.disabledByAdmin =>
        'ميزة تجربة الملابس الافتراضية متوقفة مؤقتاً من قبل الإدارة. يرجى المحاولة لاحقاً.',
      null => null,
    };
  }

  String? get blockedBadgeLabel {
    return switch (blockReason) {
      TryonBlockReason.dailyLimitReached => 'انتهت المحاولات',
      TryonBlockReason.tokensDepleted => 'متوقف مؤقتاً',
      TryonBlockReason.disabledByAdmin => 'متوقف مؤقتاً',
      null => null,
    };
  }

  TryonQuota copyWith({
    bool? enabled,
    bool? tokensAvailable,
    TryonProvider? activeProvider,
    int? sessionDurationSeconds,
    int? dailyLimit,
    int? usedToday,
    int? remainingToday,
    TryonBlockReason? blockReasonOverride,
    bool clearBlockReasonOverride = false,
  }) {
    return TryonQuota(
      enabled: enabled ?? this.enabled,
      tokensAvailable: tokensAvailable ?? this.tokensAvailable,
      activeProvider: activeProvider ?? this.activeProvider,
      sessionDurationSeconds:
          sessionDurationSeconds ?? this.sessionDurationSeconds,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      usedToday: usedToday ?? this.usedToday,
      remainingToday: remainingToday ?? this.remainingToday,
      blockReasonOverride: clearBlockReasonOverride
          ? null
          : (blockReasonOverride ?? this.blockReasonOverride),
    );
  }

  factory TryonQuota.fromMap(Map<String, dynamic> map) {
    final limit = (map['daily_limit'] as num?)?.toInt() ?? 3;
    final used = (map['used_today'] as num?)?.toInt() ?? 0;
    final remaining =
        (map['remaining_today'] as num?)?.toInt() ??
        (limit - used).clamp(0, limit);
    final duration =
        ((map['session_duration_seconds'] as num?)?.toInt() ?? 30).clamp(
          10,
          300,
        );
    final rawReason = map['block_reason']?.toString();
    final parsedReason = switch (rawReason) {
      'disabled' => TryonBlockReason.disabledByAdmin,
      'tokens_depleted' => TryonBlockReason.tokensDepleted,
      'daily_limit_reached' => TryonBlockReason.dailyLimitReached,
      _ => null,
    };
    return TryonQuota(
      enabled: map['enabled'] != false,
      tokensAvailable: map['tokens_available'] != false,
      activeProvider: TryonProvider.fromString(map['active_provider']),
      sessionDurationSeconds: duration,
      dailyLimit: limit.clamp(1, 100),
      usedToday: used.clamp(0, 1000),
      remainingToday: remaining.clamp(0, 100),
      blockReasonOverride: parsedReason,
    );
  }
}
