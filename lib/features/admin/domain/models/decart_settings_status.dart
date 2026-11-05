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
