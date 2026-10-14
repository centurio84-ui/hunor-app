import 'package:flutter/material.dart';
import '../api/rescue_platform_api.dart';
import '../models/organization.dart';
import '../theme/hunor_theme.dart';

/// OrganizationSwitcherView
/// Szervezetválasztó képernyőprototípus a többszervezetes Rescue Platform architektúrához.
/// Biztosítja a szervezetek közötti biztonságos váltást és a gyorsítótár ürítését.
class OrganizationSwitcherView extends StatefulWidget {
  final RescuePlatformApi api;
  final VoidCallback? onOrganizationChanged;

  const OrganizationSwitcherView({
    super.key,
    required this.api,
    this.onOrganizationChanged,
  });

  @override
  State<OrganizationSwitcherView> createState() => _OrganizationSwitcherViewState();
}

class _OrganizationSwitcherViewState extends State<OrganizationSwitcherView> {
  List<Organization> _organizations = [];
  Map<String, Membership> _memberships = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orgs = await widget.api.getMyOrganizations();
      final membershipsMap = <String, Membership>{};
      for (final org in orgs) {
        try {
          final m = await widget.api.getMyOrganizationMembership(org.id);
          membershipsMap[org.id] = m;
        } catch (_) {
          // Ha nincs jóváhagyott tagság
        }
      }

      if (mounted) {
        setState(() {
          _organizations = orgs;
          _memberships = membershipsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectOrganization(Organization org) async {
    if (widget.api.currentOrganizationId == org.id) return;

    try {
      await widget.api.switchOrganization(org.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HunorColors.surface2,
            content: Text(
              'Szervezet sikeresen átváltva: ${org.name}. A korábbi adatok törölve.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
        setState(() {});
        widget.onOrganizationChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HunorColors.red,
            content: Text('Hiba a szervezetváltáskor: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOrgId = widget.api.currentOrganizationId;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Szervezetválasztó',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: HunorColors.red))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: HunorColors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadOrganizations,
                          child: const Text('Újrapróbálkozás'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'ELÉRHETŐ SZERVEZETEK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: HunorColors.muted,
                        ),
                      ),
                    ),
                    for (final org in _organizations) ...[
                      _buildOrgCard(org, isSelected: org.id == currentOrgId),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }

  Widget _buildOrgCard(Organization org, {required bool isSelected}) {
    final membership = _memberships[org.id];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? HunorColors.red : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectOrganization(org),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? HunorColors.red.withOpacity(.18) : HunorColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        org.code,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isSelected ? HunorColors.red : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (org.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            org.description,
                            style: const TextStyle(fontSize: 12, color: HunorColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: HunorColors.red, size: 24),
                ],
              ),
              if (membership != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Státusz: ${membership.membershipStatus.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: membership.isApproved ? HunorColors.success : HunorColors.warning,
                      ),
                    ),
                    if (membership.positions.isNotEmpty)
                      Text(
                        membership.positions.join(', '),
                        style: const TextStyle(fontSize: 12, color: HunorColors.muted),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
