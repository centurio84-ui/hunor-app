import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';
import 'home_page.dart';
import 'alerts_page.dart';
import 'calendar_page.dart';
import 'members_page.dart';
import 'profile_page.dart';
import 'admin_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  int index = 0;
  @override Widget build(BuildContext context) {
    final admin = context.watch<AppStore>().currentUserRole == MemberRole.admin;
    final pages = <Widget>[const HomePage(), const AlertsPage(), const CalendarPage(), const MembersPage(), const ProfilePage(), if (admin) const AdminPage()];
    final labels = ['Kezdőlap','Riasztások','Naptár','Tagok','Profil', if (admin) 'Admin'];
    final icons = [Icons.home,Icons.notifications,Icons.calendar_month,Icons.people,Icons.person, if (admin) Icons.settings];
    return Scaffold(
      appBar: AppBar(title: const Text('HUNOR')),
      body: IndexedStack(index:index, children:pages),
      bottomNavigationBar: NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),
        destinations:[for(var i=0;i<labels.length;i++) NavigationDestination(icon:Icon(icons[i]),label:labels[i])]),
      floatingActionButton: admin ? FloatingActionButton(onPressed:()=>_adminInfo(context),child:const Icon(Icons.settings)) : null,
    );
  }
  void _adminInfo(BuildContext c)=>showDialog(context:c,builder:(_)=>const AlertDialog(title:Text('Admin'),content:Text('Az admin felület következő fejlesztési lépésként kerül át Flutterre.')));
}
