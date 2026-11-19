class TryonQuota {
  const TryonQuota({
    this.enabled = true,
    this.sessionDurationSeconds = 30,
    this.dailyLimit = 3,
    this.usedToday = 0,
    this.remainingToday = 3,
  });

  final bool enabled;
  final int sessionDurationSeconds;
  final int dailyLimit;
  final int usedToday;
  final int remainingToday;

  bool get hasRemaining => enabled && remainingToday > 0;

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
    return TryonQuota(
      enabled: map['enabled'] != false,
      sessionDurationSeconds: duration,
      dailyLimit: limit.clamp(1, 100),
      usedToday: used.clamp(0, 1000),
      remainingToday: remaining.clamp(0, 100),
    );
  }
}
