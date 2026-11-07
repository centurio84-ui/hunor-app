/// Server-derived operation ceilings, never a replacement for backend guards.
/// Unknown/missing actions and unknown contract versions are denied.
class OrganizationCapabilities {
  static const supportedVersion = '2026-10-22.1';
  static const _knownActions = {
    'organization.read', 'membership.read_self', 'members.read', 'events.read',
    'alerts.read', 'alerts.respond_self', 'alerts.acknowledge_self', 'coins.read_self',
    'members.manage_permissions', 'alerts.create', 'alerts.dispatch', 'alerts.close',
    'events.participate_self', 'events.manage', 'events.manage_participants',
    'news.read', 'news.manage', 'news.publish', 'profile.update_self', 'members.manage_basic',
  };
  final String organizationId;
  final String membershipId;
  final int permissionsVersion;
  final Map<String, bool> _actions;

  OrganizationCapabilities._(this.organizationId, this.membershipId,
      this.permissionsVersion, Map<String, bool> actions)
      : _actions = Map.unmodifiable(actions);

  factory OrganizationCapabilities.fromJson(Map<String, dynamic> value,
      {required String organizationId, required String membershipId,
      required int permissionsVersion}) {
    if (value['organization_id'] != organizationId ||
        value['membership_id'] != membershipId ||
        value['permissions_version'] != permissionsVersion) {
      throw const FormatException('Capability scope/version mismatch.');
    }
    final raw = value['allowed_actions'];
    final actions = <String, bool>{};
    if (value['authorization_version'] == supportedVersion && raw is Map) {
      for (final entry in raw.entries) {
        if (_knownActions.contains(entry.key) && entry.value is bool) {
          actions[entry.key as String] = entry.value as bool;
        }
      }
    }
    return OrganizationCapabilities._(
        organizationId, membershipId, permissionsVersion, actions);
  }

  bool allows(String action) => _actions[action] == true;
}
