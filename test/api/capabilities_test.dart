import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/models/organization_capabilities.dart';
import 'staging_api_test.dart' show ready, defaults, json, orgA;

const member = '44444444-4444-4444-8444-444444444444';
Map<String, dynamic> payload() => {
  'organization_id': orgA, 'membership_id': member, 'permissions_version': 1,
  'authorization_version': OrganizationCapabilities.supportedVersion,
  'allowed_actions': {'events.read': true, 'members.manage_permissions': false, 'platform.superadmin': true},
};
OrganizationCapabilities parse(Map<String, dynamic> data) =>
    OrganizationCapabilities.fromJson(data, organizationId: orgA,
        membershipId: member, permissionsVersion: 1);

void main() {
  test('server capabilities allow known booleans only, never unknown root privilege', () {
    final value = parse(payload());
    expect(value.allows('events.read'), isTrue);
    expect(value.allows('members.manage_permissions'), isFalse);
    expect(value.allows('platform.superadmin'), isFalse);
    expect(value.allows('missing'), isFalse);
  });
  test('foreign scope and stale version rejected', () {
    for (final key in ['organization_id', 'membership_id', 'permissions_version']) {
      expect(() => parse({...payload(), key: key == 'permissions_version' ? 2 : 'foreign'}), throwsFormatException);
    }
  });
  test('unknown contract and truthy strings fail closed', () {
    expect(parse({...payload(), 'authorization_version': 'future'}).allows('events.read'), isFalse);
    expect(parse({...payload(), 'allowed_actions': {'events.read': 'true'}}).allows('events.read'), isFalse);
  });
  test('old deployed API missing extension keeps member reads, no inferred admin', () async {
    final api = await ready();
    final membership = await api.getMyOrganizationMembership(orgA);
    expect(await api.getMyCapabilities(membership), isNull);
    expect(api.isAuthenticated, isTrue);
  });
  test('adapter validates new endpoint against selected tenant and fresh membership', () async {
    final api = await ready(handler: (r) => r.url.path.endsWith('/capabilities/me') ? json(payload()) : defaults(r));
    final membership = await api.getMyOrganizationMembership(orgA);
    expect((await api.getMyCapabilities(membership))!.allows('events.read'), isTrue);
  });
  test('capability forbidden error is never treated as compatibility fallback', () async {
    final api = await ready(handler: (r) => r.url.path.endsWith('/capabilities/me') ? json({'code': 'FORBIDDEN'}, 403) : defaults(r));
    await expectLater(api.getMyCapabilities(await api.getMyOrganizationMembership(orgA)), throwsA(isA<Exception>()));
  });
}
