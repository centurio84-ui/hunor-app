import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';
import 'home_page.dart';
import 'alerts_page.dart';
import 'calendar_page.dart';
import 'members_page.dart';
import 'profile_page.dart';
import 'admin_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AppStore>().currentUserRole == MemberRole.admin;
    final pages = <Widget>[
      const HomePage(),
      const AlertsPage(),
      const CalendarPage(),
      const MembersPage(),
      const ProfilePage(),
      if (admin) const AdminPage(),
    ];
    final labels = [
      'Főoldal',
      'Riasztások',
      'Naptár',
      'Állomány',
      'Profil',
      if (admin) 'Admin',
    ];
    final icons = [
      Icons.home_rounded,
      Icons.warning_amber_rounded,
      Icons.calendar_month_rounded,
      Icons.groups_rounded,
      Icons.person_rounded,
      if (admin) Icons.admin_panel_settings_rounded,
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 28,
              decoration: BoxDecoration(
                color: HunorColors.red,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'HUNOR',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(
              icon: Icon(icons[i]),
              selectedIcon: Icon(icons[i]),
              label: labels[i],
            ),
        ],
      ),
      floatingActionButton: admin
          ? FloatingActionButton(
              backgroundColor: HunorColors.red,
              foregroundColor: Colors.white,
              onPressed: () => _adminInfo(context),
              child: const Icon(Icons.admin_panel_settings_rounded),
            )
          : null,
    );
  }

  void _adminInfo(BuildContext c) => showDialog(
        context: c,
        builder: (_) => const AlertDialog(
          title: Text('Admin'),
          content: Text(
            'Az admin felület következő fejlesztési lépésként kerül továbbépítésre.',
          ),
        ),
      );
}
