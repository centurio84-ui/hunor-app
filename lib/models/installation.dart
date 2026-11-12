/// Eszközregisztrációs és push értesítési modellek a Rescue Platformhoz.

class Installation {
  final String id;
  final String platform; // 'ios', 'android'
  final String provider; // 'fcm', 'apns'
  final String environment; // 'development', 'production'
  final String label;
  final bool active;
  final int version;

  const Installation({
    required this.id,
    required this.platform,
    required this.provider,
    required this.environment,
    required this.label,
    required this.active,
    this.version = 1,
  });

  factory Installation.fromJson(Map<String, dynamic> json) {
    return Installation(
      id: json['id']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      environment: json['environment']?.toString() ?? 'development',
      label: json['label']?.toString() ?? '',
      active: json['active'] as bool? ?? true,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'platform': platform,
    'provider': provider,
    'environment': environment,
    'label': label,
    'active': active,
    'version': version,
  };
}

class DeviceReceipt {
  final bool received;
  final DateTime? receivedAt;

  const DeviceReceipt({
    required this.received,
    this.receivedAt,
  });

  factory DeviceReceipt.fromJson(Map<String, dynamic> json) {
    return DeviceReceipt(
      received: json['received'] as bool? ?? false,
      receivedAt: json['received_at'] != null ? DateTime.tryParse(json['received_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'received': received,
    if (receivedAt != null) 'received_at': receivedAt!.toIso8601String(),
  };
}
