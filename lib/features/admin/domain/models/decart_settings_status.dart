import '../../../virtual_tryon/domain/tryon_provider.dart';

export '../../../virtual_tryon/domain/tryon_provider.dart';

class DecartSettingsStatus {
  const DecartSettingsStatus({
    required this.configured,
    this.updatedAt,
    this.totalKeys = 0,
    this.activeKeys = 0,
  });

  final bool configured;
  final DateTime? updatedAt;
  final int totalKeys;
  final int activeKeys;

  factory DecartSettingsStatus.fromMap(Map<String, dynamic> data) =>
      DecartSettingsStatus(
        configured: data['configured'] == true,
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
        totalKeys: (data['total_keys'] as num?)?.toInt() ?? 0,
        activeKeys: (data['active_keys'] as num?)?.toInt() ?? 0,
      );
}

class TryonCostControls {
  const TryonCostControls({
    this.enabled = true,
    this.sessionDurationSeconds = 30,
    this.dailyAttemptsLimit = 3,
    this.activeProvider = TryonProvider.decart,
    this.updatedAt,
  });

  final bool enabled;
  final int sessionDurationSeconds;
  final int dailyAttemptsLimit;
  final TryonProvider activeProvider;
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
        activeProvider: TryonProvider.fromString(data['active_provider']),
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
      );
}

class DecartApiKeyEntry {
  const DecartApiKeyEntry({
    required this.label,
    required this.keyHint,
    this.id,
    this.priority = 100,
    this.isActive = true,
    this.credits,
    this.usd,
    this.status = 'unknown',
    this.errorCode,
    this.lastUsedAt,
  });

  final String? id;
  final String label;
  final String keyHint;
  final int priority;
  final bool isActive;
  final double? credits;
  final double? usd;
  final String status; // 'active' | 'low' | 'depleted' | 'invalid' | 'unknown'
  final String? errorCode;
  final DateTime? lastUsedAt;

  bool get hasUsd => usd != null;

  String get formattedCredits {
    final c = credits;
    if (c == null) return '--';
    if (c >= 1000) return c.toStringAsFixed(0);
    return c.truncateToDouble() == c
        ? c.toStringAsFixed(0)
        : c.toStringAsFixed(1);
  }

  String get formattedUsd {
    final u = usd;
    if (u == null) return '--';
    return '\$${u.toStringAsFixed(2)}';
  }

  factory DecartApiKeyEntry.fromMap(
    Map<String, dynamic> data, {
    bool estimateDecartUsd = true,
  }) {
    final rawCredits = data['credits'] ?? data['last_credits'];
    final parsedCredits = rawCredits is num
        ? rawCredits.toDouble()
        : double.tryParse(rawCredits?.toString() ?? '');
    final hasExplicitUsd = data.containsKey('usd');
    final rawUsd = data['usd'];
    final parsedUsd = rawUsd is num
        ? rawUsd.toDouble()
        : (!hasExplicitUsd && estimateDecartUsd && parsedCredits != null
              ? parsedCredits / 100
              : null);
    return DecartApiKeyEntry(
      id: data['id']?.toString(),
      label: data['label']?.toString() ?? 'API Key',
      keyHint:
          data['keyHint']?.toString() ?? data['key_hint']?.toString() ?? '…',
      priority: (data['priority'] as num?)?.toInt() ?? 100,
      isActive: (data['isActive'] ?? data['is_active']) != false,
      credits: parsedCredits,
      usd: parsedUsd,
      status:
          data['status']?.toString() ??
          data['last_status']?.toString() ??
          'unknown',
      errorCode: data['errorCode']?.toString(),
      lastUsedAt: DateTime.tryParse(
        data['lastUsedAt']?.toString() ?? data['last_used_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

class DecartCreditsBalance {
  const DecartCreditsBalance({
    required this.configured,
    this.provider = TryonProvider.decart,
    this.credits,
    this.usd,
    this.totalKeys = 0,
    this.activeKeys = 0,
    this.depletedKeys = 0,
    this.invalidKeys = 0,
    this.checkedAt,
    this.errorCode,
    this.needsFunctionDeploy = false,
    this.keys = const [],
  });

  final bool configured;
  final TryonProvider provider;
  final double? credits;
  final double? usd;
  final int totalKeys;
  final int activeKeys;
  final int depletedKeys;
  final int invalidKeys;
  final DateTime? checkedAt;
  final String? errorCode;
  final bool needsFunctionDeploy;
  final List<DecartApiKeyEntry> keys;

  bool get hasBalance => credits != null && errorCode == null;
  bool get hasUsd => usd != null;
  bool get isInvalidKey => errorCode == 'invalid_key';
  bool get isDepleted => hasBalance && credits! <= 0;
  bool get isLow => hasBalance && credits! > 0 && credits! < 100;

  String get formattedCredits {
    final c = credits;
    if (c == null) return '--';
    if (c >= 1000) {
      return c.toStringAsFixed(0);
    }
    return c.truncateToDouble() == c
        ? c.toStringAsFixed(0)
        : c.toStringAsFixed(1);
  }

  String get formattedUsd {
    final u = usd;
    if (u == null) return '--';
    return '\$${u.toStringAsFixed(2)}';
  }

  factory DecartCreditsBalance.fromMap(
    Map<String, dynamic> data, {
    TryonProvider defaultProvider = TryonProvider.decart,
  }) {
    final provider = data['provider'] != null
        ? TryonProvider.fromString(data['provider'])
        : defaultProvider;
    final estimateUsd = provider == TryonProvider.decart;
    final rawCredits = data['credits'];
    final parsedCredits = rawCredits is num
        ? rawCredits.toDouble()
        : double.tryParse(rawCredits?.toString() ?? '');
    final hasExplicitUsd = data.containsKey('usd');
    final rawUsd = data['usd'];
    final parsedUsd = rawUsd is num
        ? rawUsd.toDouble()
        : (!hasExplicitUsd && estimateUsd && parsedCredits != null
              ? parsedCredits / 100
              : null);
    final rawKeys = data['keys'] is List ? data['keys'] as List : const [];
    final parsedKeys = rawKeys
        .map(
          (e) => DecartApiKeyEntry.fromMap(
            Map<String, dynamic>.from(e as Map),
            estimateDecartUsd: estimateUsd,
          ),
        )
        .toList();
    return DecartCreditsBalance(
      configured: data['configured'] == true,
      provider: provider,
      credits: parsedCredits,
      usd: parsedUsd,
      totalKeys: (data['totalKeys'] as num?)?.toInt() ?? parsedKeys.length,
      activeKeys: (data['activeKeys'] as num?)?.toInt() ?? 0,
      depletedKeys: (data['depletedKeys'] as num?)?.toInt() ?? 0,
      invalidKeys: (data['invalidKeys'] as num?)?.toInt() ?? 0,
      checkedAt: DateTime.tryParse(
        data['checkedAt']?.toString() ?? data['checked_at']?.toString() ?? '',
      )?.toLocal(),
      errorCode: data['errorCode']?.toString(),
      keys: parsedKeys,
    );
  }
}
