import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../services/app_store.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(title: const Text('Tagok'), trailing: Text(s.members.length.toString()))),
        Card(child: ListTile(title: const Text('Események'), trailing: Text(s.events.length.toString()))),
        ListTile(title: const Text('Tagok'), leading: const Icon(Icons.people)),
        ...s.members.map((m) => ListTile(
          title: Text(m.name), subtitle: Text((m.rank.isEmpty ? m.position : m.rank) + ' • ' + m.status.label),
          onTap: () => _editMember(context, m),
        )),
        const Divider(),
        ListTile(title: const Text('Riasztások'), leading: const Icon(Icons.notifications),
          trailing: FilledButton.icon(onPressed: () => _editAlert(context), icon: const Icon(Icons.add), label: const Text('Új'))),
        ...s.alerts.where((a) => a.status == 'active').take(10).map((a) => ListTile(
          title: Text(a.title), subtitle: Text(a.typeLabel + ' • ' + a.message),
        )),
        const Divider(),
        ListTile(title: const Text('Események'), leading: const Icon(Icons.calendar_month),
          trailing: FilledButton.icon(onPressed: () => _editEvent(context), icon: const Icon(Icons.add), label: const Text('Új'))),
        ...s.events.map((e) => ListTile(title: Text(e.title), subtitle: Text(e.location),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => s.deleteEvent(e.id)),
          onTap: () => _editEvent(context, e))),
      ]),
    );
  }

  void _editMember(BuildContext context, Member member) {
    final s = context.read<AppStore>();
    final name = TextEditingController(text: member.name), rank = TextEditingController(text: member.rank);
    final workplace = TextEditingController(text: member.workplace), position = TextEditingController(text: member.position);
    final phone = TextEditingController(text: member.phone);
    var role = s.currentUserRole;
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

  void _editEvent(BuildContext context, [HunorEvent? event]) {
    final s = context.read<AppStore>();
    final title = TextEditingController(text: event?.title ?? ''), location = TextEditingController(text: event?.location ?? '');
    final details = TextEditingController(text: event?.details ?? '');
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
          if (event == null) await s.createEvent(title.text.trim(), date, location.text, details.text);
          else await s.updateEvent(event.id, title.text.trim(), date, location.text, details.text);
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