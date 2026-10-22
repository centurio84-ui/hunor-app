import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';
import 'alerts_page.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'organization_switcher_view.dart';
import 'profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  Timer? _timer;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_timer=Timer.periodic(const Duration(seconds:30),(_){if(mounted)context.read<AppStore>().syncPendingResponses();});}
  @override void dispose(){_timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)context.read<AppStore>().syncPendingResponses();}
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final currentOrg = store.currentOrganization;
    final coin = store.coinBalance;

    final pages = <Widget>[
      const HomePage(),
      const AlertsPage(),
      const CalendarPage(),
      const ProfilePage(),
      OrganizationSwitcherView(
        api: store.api,
        onOrganizationChanged: () => store.loadData(),
      ),
    ];

    final labels = [
      'Főoldal',
      'Riasztások',
      'Naptár',
      'Profil',
      'Szervezetek',
    ];

    final icons = [
      Icons.home_rounded,
      Icons.warning_amber_rounded,
      Icons.calendar_month_rounded,
      Icons.person_rounded,
      Icons.business_rounded,
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => index = 4), // Szervezetválasztó
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HunorColors.redDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    currentOrg?.code ?? 'RESCUE',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    currentOrg?.name ?? 'Rescue Platform',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: HunorColors.muted),
              ],
            ),
          ),
        ),
        actions: [
          if (store.showRescueCoins && coin != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Icon(Icons.monetization_on_outlined, size: 16, color: HunorColors.warning),
                label: Text(
                  '${coin.balance} ${coin.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                backgroundColor: HunorColors.surface2,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
      ),
      body: Column(children:[
        if(store.isStaging) const MaterialBanner(content:Text('STAGING TESZT · fiktív adatok · nincs valódi riasztásküldés'),actions:[SizedBox.shrink()]),
        if(store.errorMessage!=null) Padding(padding:const EdgeInsets.all(8),child:Text(store.errorMessage!,style:const TextStyle(color:HunorColors.warning))),
        if(store.isStaging) Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text('Várakozó válaszok: ${store.pendingResponses.length}'),TextButton(onPressed:store.syncPendingResponses,child:const Text('Szinkronizálás'))]),
        for(final q in store.pendingResponses) ListTile(dense:true,title:Text(q['blocked']==true?'Nem küldhető: ${q['error']}':'Szerveres megerősítésre vár'),trailing:TextButton(onPressed:()=>store.discardPendingResponse(q['key'] as String),child:const Text('Elvetés'))),
        Expanded(child:IndexedStack(index:index,children:pages)),
      ]),
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
    );
  }
}
