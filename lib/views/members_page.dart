import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
  @override State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final query = q.toLowerCase().trim();
    final list = s.members.where((m) =>
      m.name.toLowerCase().contains(query) ||
      m.skills.any((x) => x.toLowerCase().contains(query))
    ).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Név vagy képesség',
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Nincs találat', style: TextStyle(color: HunorColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final m = list[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: HunorColors.surface2,
                          child: Text(m.name.isEmpty ? '?' : m.name.substring(0, 1).toUpperCase()),
                        ),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${m.rank} • ${m.position}\n${m.status.label}',
                          style: const TextStyle(color: HunorColors.muted),
                        ),
                        isThreeLine: true,
                        trailing: Icon(Icons.chevron_right, color: _statusColor(m.status)),
                        onTap: () => _openMember(context, m),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _statusColor(AvailabilityStatus status) => switch (status) {
    AvailabilityStatus.available => HunorColors.success,
    AvailabilityStatus.vacation => HunorColors.warning,
    AvailabilityStatus.sick => HunorColors.red,
    AvailabilityStatus.training => HunorColors.exercise,
    AvailabilityStatus.unavailable => HunorColors.muted,
  };

  void _openMember(BuildContext context, Member member) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: HunorColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: HunorColors.redDark,
                    child: Text(
                      member.name.isEmpty ? '?' : member.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 3),
                        Text(member.rank, style: const TextStyle(color: HunorColors.red, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  _StatusChip(status: member.status),
                ],
              ),
              const SizedBox(height: 20),
              _InfoRow(Icons.work_outline, 'Beosztás', member.position),
              _InfoRow(Icons.business_outlined, 'Szervezet', member.workplace),
              if (member.phone.isNotEmpty) _InfoRow(Icons.phone_outlined, 'Telefon', member.phone),
              const SizedBox(height: 16),
              const Text('KÉPESSÉGEK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: HunorColors.muted)),
              const SizedBox(height: 8),
              if (member.skills.isEmpty)
                const Text('Nincs megadott képesség', style: TextStyle(color: HunorColors.muted))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [for (final skill in member.skills) Chip(label: Text(skill))]),
              if (member.phone.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri(scheme: 'tel', path: member.phone);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Telefonhívás'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AvailabilityStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AvailabilityStatus.available => HunorColors.success,
      AvailabilityStatus.vacation => HunorColors.warning,
      AvailabilityStatus.sick => HunorColors.red,
      AvailabilityStatus.training => HunorColors.exercise,
      AvailabilityStatus.unavailable => HunorColors.muted,
    };
    return Chip(avatar: Icon(Icons.circle, size: 10, color: color), label: Text(status.label));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: HunorColors.muted, size: 20),
        const SizedBox(width: 12),
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: HunorColors.muted, fontSize: 12))),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    ),
  );
}
