/// Többszervezetes (Multi-tenant) adatmodellek a Rescue Platformhoz.

enum MembershipStatus {
  pending,
  approved,
  suspended,
  revoked;

  static MembershipStatus fromString(String? value) {
    return switch (value) {
      'approved' => MembershipStatus.approved,
      'suspended' => MembershipStatus.suspended,
      'revoked' => MembershipStatus.revoked,
      _ => MembershipStatus.pending,
    };
  }

  String get label => switch (this) {
    MembershipStatus.approved => 'Jóváhagyva',
    MembershipStatus.pending => 'Jóváhagyásra vár',
    MembershipStatus.suspended => 'Felfüggesztve',
    MembershipStatus.revoked => 'Visszavonva',
  };
}

class Organization {
  final String id;
  final String name;
  final String code;
  final String description;
  final bool active;

  const Organization({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
    this.active = true,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'description': description,
    'active': active,
  };
}

class Membership {
  final String id;
  final String organizationId;
  final String userId;
  final String displayName;
  final MembershipStatus membershipStatus;
  final List<String> positions;
  final List<String> skills;
  final bool alertable;
  final List<String> permissions;
  final int permissionsVersion;
  final int version;

  const Membership({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.displayName,
    required this.membershipStatus,
    this.positions = const [],
    this.skills = const [],
    this.alertable = false,
    this.permissions = const [],
    this.permissionsVersion = 1,
    this.version = 1,
  });

  bool get isApproved => membershipStatus == MembershipStatus.approved;
  bool hasPermission(String permission) => permissions.contains(permission);

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id']?.toString() ?? '',
      organizationId: json['organization_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      membershipStatus: MembershipStatus.fromString(json['membership_status']?.toString()),
      positions: (json['positions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      skills: (json['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      alertable: json['alertable'] as bool? ?? false,
      permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      permissionsVersion: (json['permissions_version'] as num?)?.toInt() ?? 1,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'user_id': userId,
    'display_name': displayName,
    'membership_status': membershipStatus.name,
    'positions': positions,
    'skills': skills,
    'alertable': alertable,
    'permissions': permissions,
    'permissions_version': permissionsVersion,
    'version': version,
  };
}
