import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/navigation_tab.dart';
import '../services/navigation_controller.dart';
import 'home_page.dart';
import 'alerts_page.dart';
import 'calendar_page.dart';
import 'members_page.dart';
import 'profile_page.dart';
import 'admin_page.dart';
import 'navigation_gate.dart';
import 'navigation_settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialRoute = '/home'});
  final String initialRoute;
  @override
  State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late String selectedPath;
  static final Map<String, WidgetBuilder> pages = {
    '/home': (_) => const HomePage(), '/alerts': (_) => const AlertsPage(),
    '/calendar': (_) => const CalendarPage(), '/members': (_) => const MembersPage(),
    '/profile': (_) => const ProfilePage(), '/admin': (_) => const AdminPage(),
    '/navigation-settings': (_) => const NavigationSettingsPage(),
  };
  static const icons = {'home': Icons.home_rounded, 'notifications_active': Icons.warning_amber_rounded,
    'calendar_month': Icons.calendar_month_rounded, 'groups': Icons.groups_rounded,
    'person': Icons.person_rounded, 'admin_panel_settings': Icons.admin_panel_settings_rounded};
  @override
  void initState() {
    super.initState(); selectedPath = widget.initialRoute == '/' ? '/home' : Uri.parse(widget.initialRoute).path;
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<NavigationController>().refresh();
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  void select(String path) {scaffoldKey.currentState?.closeDrawer();setState(() => selectedPath = path);}
  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationController>();
    final tabs = navigation.tabs.where((t) => pages.containsKey(t.routePath) && navigation.canOpen(t.routePath)).toList();
    if (navigation.isAdmin && navigation.ready && navigation.isApproved) {
      tabs.add(const NavigationTab(id: 'navigation-settings', title: 'Menük kezelése',
        routePath: '/navigation-settings', iconName: 'admin_panel_settings', isVisible: true, sortOrder: 999));
    }
    final selectedIndex = tabs.indexWhere((t) => t.routePath == selectedPath);
    final wide = MediaQuery.sizeOf(context).width >= 850;
    Widget label(NavigationTab tab) => Column(mainAxisSize: MainAxisSize.min, children: [
      Text(tab.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (navigation.isAdmin && !tab.isVisible) const Text('Rejtett', style: TextStyle(fontSize: 10, color: Colors.amber)),
    ]);
    final body = NavigationGate(path: selectedPath,
      builder: pages[selectedPath] ?? (_) => const Center(child: Text('Ez az oldal ebben a kliensben még nem érhető el.')));
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(title: const Text('HUNOR')),
      drawer: wide && tabs.length >= 2 ? null : Drawer(child: SafeArea(child: ListView(children: [
        const ListTile(title: Text('HUNOR menü')),
        for (final tab in tabs) ListTile(leading: Icon(icons[tab.iconName] ?? Icons.apps_rounded),
          title: label(tab), selected: selectedPath == tab.routePath, onTap: () => select(tab.routePath)),
      ]))),
      body: Row(children: [
        if (wide && tabs.length >= 2) NavigationRail(
          selectedIndex: selectedIndex < 0 ? null : selectedIndex,
          onDestinationSelected: (index) => setState(() => selectedPath = tabs[index].routePath),
          labelType: NavigationRailLabelType.all,
          destinations: [for (final tab in tabs) NavigationRailDestination(
            icon: Icon(icons[tab.iconName] ?? Icons.apps_rounded), label: label(tab))],
        ), Expanded(child: body),
      ]),
      bottomNavigationBar: !wide && tabs.length >= 2 && tabs.length <= 5 ? NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedPath = tabs[index].routePath),
        destinations: [for (final tab in tabs) NavigationDestination(
          icon: Icon(icons[tab.iconName] ?? Icons.apps_rounded), label: !tab.isVisible ? '${tab.title} · Rejtett' : tab.title,
          tooltip: !tab.isVisible ? '${tab.title} · Rejtett' : tab.title)],
      ) : null,
    );
  }
}
