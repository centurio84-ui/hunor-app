/// Riasztási és bevetési modellek a Rescue Platformhoz.

class RescueAlert {
  final String id;
  final String organizationId;
  final String title;
  final String message;
  final String type; // 'alert', 'exercise', 'standby'
  final String status; // 'active', 'closed', 'expired'
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int version;

  const RescueAlert({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.message,
    required this.type,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.version = 1,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isActive => status == 'active' && !isExpired;

  String get typeLabel => switch (type) {
    'exercise' => 'GYAKORLAT',
    'standby' => 'KÉSZENLÉTBE HELYEZÉS',
    _ => 'RIASZTÁS',
  };

  factory RescueAlert.fromJson(Map<String, dynamic> json) {
    return RescueAlert(
      id: json['id']?.toString() ?? '',
      organizationId: json['organization_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'alert',
      status: json['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'title': title,
    'message': message,
    'type': type,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    'version': version,
  };
}

class AlertResponse {
  final String alertId;
  final String membershipId;
  final String response; // 'going', 'not_going', 'available', 'unavailable'
  final DateTime? respondedAt;
  final int version;

  const AlertResponse({
    required this.alertId,
    required this.membershipId,
    required this.response,
    this.respondedAt,
    this.version = 1,
  });

  factory AlertResponse.fromJson(Map<String, dynamic> json) {
    return AlertResponse(
      alertId: json['alert_id']?.toString() ?? '',
      membershipId: json['membership_id']?.toString() ?? '',
      response: json['response']?.toString() ?? '',
      respondedAt: json['responded_at'] != null ? DateTime.tryParse(json['responded_at'].toString()) : null,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'alert_id': alertId,
    'membership_id': membershipId,
    'response': response,
    if (respondedAt != null) 'responded_at': respondedAt!.toIso8601String(),
    'version': version,
  };
}
