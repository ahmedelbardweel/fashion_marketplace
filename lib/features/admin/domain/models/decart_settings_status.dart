class DecartSettingsStatus {
  const DecartSettingsStatus({required this.configured, this.updatedAt});

  final bool configured;
  final DateTime? updatedAt;

  factory DecartSettingsStatus.fromMap(Map<String, dynamic> data) =>
      DecartSettingsStatus(
        configured: data['configured'] == true,
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
      );
}

class TryonCostControls {
  const TryonCostControls({
    this.enabled = true,
    this.sessionDurationSeconds = 30,
    this.dailyAttemptsLimit = 3,
    this.updatedAt,
  });

  final bool enabled;
  final int sessionDurationSeconds;
  final int dailyAttemptsLimit;
  final DateTime? updatedAt;

  factory TryonCostControls.fromMap(Map<String, dynamic> data) =>
      TryonCostControls(
        enabled: data['enabled'] != false,
        sessionDurationSeconds:
            ((data['session_duration_seconds'] as num?)?.toInt() ?? 30).clamp(
              10,
              300,
            ),
        dailyAttemptsLimit:
            ((data['daily_attempts_limit'] as num?)?.toInt() ?? 3).clamp(
              1,
              100,
            ),
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
      );
}
