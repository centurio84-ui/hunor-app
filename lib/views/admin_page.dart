import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/event_quiz/event_quiz_admin_screen.dart';
import '../models/member.dart';
import '../models/rescue_alert.dart';
import '../models/rescue_event.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Scaffold(
      backgroundColor: HunorColors.graphite,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: HunorColors.redDark, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.admin_panel_settings_outlined)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Adminisztráció', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text('HUNOR műveleti rendszer', style: TextStyle(color: HunorColors.muted)),
            ])),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _MetricCard(Icons.people_alt_outlined, s.members.length.toString(), 'Tag')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(Icons.calendar_month_outlined, s.events.length.toString(), 'Esemény')),
            const SizedBox(width: 10),
            Expanded(child: _MetricCard(Icons.warning_amber_rounded, s.alerts.where((a) => a.status == 'active').length.toString(), 'Aktív')),
          ]),
          const SizedBox(height: 18),
          _SectionHeader('RENDEZVÉNY KVÍZEK', Icons.qr_code_2_rounded),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HunorColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFF59E0B)),
              ),
              title: const Text(
                'Rendezvény kvízek',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                '5 témakör, élő statisztika és nyomtatható QR plakát',
                style: TextStyle(color: HunorColors.muted, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: HunorColors.muted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EventQuizAdminScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SectionHeader('ÁLLOMÁNY', Icons.people_outline),
          Card(child: Column(children: [
            for (final m in s.members)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: CircleAvatar(backgroundColor: HunorColors.surface2, child: Text(m.name.isEmpty ? '?' : m.name.substring(0, 1).toUpperCase())),
                title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text((m.rank.isEmpty ? m.position : m.rank) + ' • ' + m.status.label, style: const TextStyle(color: HunorColors.muted)),
                trailing: const Icon(Icons.chevron_right, color: HunorColors.muted),
                onTap: () => _editMember(context, m),
              ),
          ])),
          const SizedBox(height: 14),
          _SectionHeader('RIASZTÁSOK', Icons.notifications_active_outlined),
          Card(child: Column(children: [
            Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _editAlert(context), icon: const Icon(Icons.add_alert), label: const Text('Új riasztás')))),
            for (final a in s.alerts.where((a) => a.status == 'active').take(10))
              _AdminAlertTile(alert: a, onResponses: () => _showAlertResponses(context, a), onClose: () async {
                await s.closeAlert(a.id);
              }),
          ])),
          const SizedBox(height: 14),
          _SectionHeader('ESEMÉNYEK', Icons.calendar_month_outlined),
          Card(child: Column(children: [
            Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _editEvent(context), icon: const Icon(Icons.add), label: const Text('Új esemény')))),
            for (final e in s.events)
              ListTile(title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(e.location, style: const TextStyle(color: HunorColors.muted)), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => s.deleteEvent(e.id)), onTap: () => _editEvent(context, e)),
          ])),
        ],
      ),
    );
  }

  void _showAlertResponses(BuildContext context, RescueAlert alert) {
    final s = context.read<AppStore>();
    final responses = s.alertResponseByMember[alert.id] ?? {};
    final available = s.members.where((m) => responses[m.id] == 'available').toList();
    final unavailable = s.members.where((m) => responses[m.id] == 'unavailable').toList();
    final unanswered = s.members.where((m) => !responses.containsKey(m.id)).toList();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: HunorColors.surface,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .78,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('${available.length} elérhető • ${unavailable.length} nem elérhető • ${unanswered.length} nem válaszolt',
                          style: const TextStyle(color: HunorColors.muted)),
                    ],
                  ),
                ),
                const TabBar(tabs: [
                  Tab(text: 'Elérhető'),
                  Tab(text: 'Nem'),
                  Tab(text: 'Nincs válasz'),
                ]),
                Expanded(
                  child: TabBarView(children: [
                    _ResponseList(members: available, empty: 'Nincs elérhetőnek jelölt tag.'),
                    _ResponseList(members: unavailable, empty: 'Nincs nem elérhetőnek jelölt tag.'),
                    _ResponseList(members: unanswered, empty: 'Minden tag válaszolt.'),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editMember(BuildContext context, Member member) {
    final s = context.read<AppStore>();
    final name = TextEditingController(text: member.name), rank = TextEditingController(text: member.rank);
    final workplace = TextEditingController(text: member.workplace), position = TextEditingController(text: member.position), phone = TextEditingController(text: member.phone);
    var role = s.roleForMember(member.id);
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: const Text('Tag szerkesztése'),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Név')),
        TextField(controller: rank, decoration: const InputDecoration(labelText: 'Rendfokozat')),
        TextField(controller: workplace, decoration: const InputDecoration(labelText: 'Munkahely')),
        TextField(controller: position, decoration: const InputDecoration(labelText: 'Beosztás')),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefonszám')),
        DropdownButton<MemberRole>(value: role, isExpanded: true, items: const [
          DropdownMenuItem(value: MemberRole.member, child: Text('Tag')),
          DropdownMenuItem(value: MemberRole.admin, child: Text('Admin')),
        ], onChanged: (v) { if (v != null) set(() => role = v); }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Mégse')),
        FilledButton(onPressed: () async {
          if (name.text.trim().isEmpty) return;
          await s.updateMember(member, name: name.text.trim(), rank: rank.text, workplace: workplace.text, position: position.text, phone: phone.text);
          await s.updateMemberRole(member.id, role);
          if (c.mounted) Navigator.pop(c);
        }, child: const Text('Mentés')),
      ],
    )));
  }

  void _editEvent(BuildContext context, [RescueEvent? event]) {
    final s = context.read<AppStore>();
    final title = TextEditingController(text: event?.title ?? ''), location = TextEditingController(text: event?.location ?? ''), details = TextEditingController(text: event?.details ?? '');
    var date = event?.date ?? DateTime.now().add(const Duration(days: 1));
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: Text(event == null ? 'Új esemény' : 'Esemény szerkesztése'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Megnevezés')),
        TextField(controller: location, decoration: const InputDecoration(labelText: 'Helyszín')),
        TextField(controller: details, decoration: const InputDecoration(labelText: 'Leírás')),
        ListTile(title: const Text('Időpont'), subtitle: Text(date.toString()), onTap: () async {
          final d = await showDatePicker(context: c, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
          if (d != null) set(() => date = DateTime(d.year, d.month, d.day, date.hour, date.minute));
        }),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Mégse')),
        FilledButton(onPressed: () async {
          if (title.text.trim().isEmpty) return;
          if (event == null) await s.createEvent(title.text.trim(), date, location.text, details.text); else await s.updateEvent(event.id, title.text.trim(), date, location.text, details.text);
          if (c.mounted) Navigator.pop(c);
        }, child: const Text('Mentés')),
      ],
    )));
  }

  void _editAlert(BuildContext context) {
    final s = context.read<AppStore>();
    final title = TextEditingController(), message = TextEditingController();
    var type = 'alert';
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: const Text('Új riasztás'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Cím')),
        TextField(controller: message, maxLines: 5, decoration: const InputDecoration(labelText: 'Üzenet')),
        DropdownButton<String>(value: type, isExpanded: true, items: const [
          DropdownMenuItem(value: 'exercise', child: Text('Gyakorlat')),
          DropdownMenuItem(value: 'standby', child: Text('Készenlétbe helyezés')),
          DropdownMenuItem(value: 'alert', child: Text('Riasztás')),
        ], onChanged: (v) { if (v != null) set(() => type = v); }),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Mégse')),
        FilledButton(onPressed: () async {
          if (title.text.trim().isEmpty || message.text.trim().isEmpty) return;
          await s.createAlert(title.text.trim(), message.text.trim(), type, null);
          if (c.mounted) Navigator.pop(c);
        }, child: const Text('Küldés')),
      ],
    )));
  }
}

class _AdminAlertTile extends StatelessWidget {
  final RescueAlert alert;
  final VoidCallback onResponses;
  final VoidCallback onClose;
  const _AdminAlertTile({required this.alert, required this.onResponses, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final responses = s.alertResponseByMember[alert.id] ?? {};
    final available = responses.values.where((x) => x == 'available').length;
    final unavailable = responses.values.where((x) => x == 'unavailable').length;
    final color = alert.type == 'standby' ? HunorColors.warning : alert.type == 'exercise' ? HunorColors.exercise : HunorColors.red;

    return ListTile(
      leading: Icon(alert.type == 'alert' ? Icons.warning_amber_rounded : Icons.notifications_active, color: color),
      title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${alert.typeLabel} • $available elérhető • $unavailable nem • ${s.members.length - responses.length} nincs válasz',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onResponses,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'responses') onResponses();
          if (v == 'close') onClose();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'responses', child: Text('Válaszok megtekintése')),
          PopupMenuItem(value: 'close', child: Text('Riasztás lezárása')),
        ],
      ),
    );
  }
}

class _ResponseList extends StatelessWidget {
  final List<Member> members;
  final String empty;
  const _ResponseList({required this.members, required this.empty});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return Center(child: Text(empty, style: const TextStyle(color: HunorColors.muted)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: HunorColors.surface2,
            child: Text(m.name.isEmpty ? '?' : m.name.substring(0, 1).toUpperCase()),
          ),
          title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(m.rank + (m.position.isEmpty ? '' : ' • ' + m.position),
              style: const TextStyle(color: HunorColors.muted)),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon; final String value, label;
  const _MetricCard(this.icon, this.value, this.label);
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8), child: Column(children: [
    Icon(icon, color: HunorColors.red), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 11, color: HunorColors.muted)),
  ])));
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader(this.title, this.icon);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 6), child: Row(children: [Icon(icon, size: 17, color: HunorColors.muted), const SizedBox(width: 7), Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: HunorColors.muted))]));
}
