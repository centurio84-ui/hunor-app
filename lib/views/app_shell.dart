import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';
import 'alerts_page.dart';
import 'calendar_page.dart';
import 'excon_dashboard_screen.dart';
import 'excon_screen.dart';
import 'home_page.dart';
import 'news_feed_page.dart';
import 'organization_switcher_view.dart';
import 'participant_evaluation_hub_screen.dart';
import 'profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kReleaseMode) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) context.read<AppStore>().syncPendingResponses();
      });
    }
  }
  @override void dispose(){_timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)context.read<AppStore>().syncPendingResponses();}
  int index = 0;

  int _bottomNavIndex(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return 0; // Főoldal
      case 1:
        return 1; // Riasztások
      case 2:
        return 2; // Naptár
      case 3:
        return 3; // Hírek
      case 7:
        return 4; // Profil
      default:
        return 0;
    }
  }

  int _pageIndexFromNav(int navIndex) {
    switch (navIndex) {
      case 0:
        return 0; // Főoldal
      case 1:
        return 1; // Riasztások
      case 2:
        return 2; // Naptár
      case 3:
        return 3; // Hírek
      case 4:
        return 7; // Profil
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final currentOrg = store.currentOrganization;
    final coin = store.coinBalance;

    final pages = <Widget>[
      const HomePage(),
      const AlertsPage(),
      const CalendarPage(),
      const NewsFeedPage(),
      const ExconScreen(),
      const ExconDashboardScreen(),
      const ParticipantEvaluationHubScreen(),
      const ProfilePage(),
      OrganizationSwitcherView(
        api: store.api,
        onOrganizationChanged: () => store.loadData(),
      ),
    ];

    return Scaffold(
      drawer: Drawer(
        backgroundColor: HunorColors.graphite,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: HunorColors.surface1,
                border: Border(bottom: BorderSide(color: HunorColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: HunorColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          'assets/images/hunor_logo.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentOrg?.name ?? 'HUNOR USAR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const Text(
                              'Műveleti Rendszer',
                              style: TextStyle(color: HunorColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_rounded, color: HunorColors.muted),
              title: const Text('Főoldal'),
              selected: index == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: HunorColors.muted),
              title: const Text('Riasztások'),
              selected: index == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded, color: HunorColors.muted),
              title: const Text('Naptár'),
              selected: index == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.newspaper_rounded, color: HunorColors.muted),
              title: const Text('Hírek'),
              selected: index == 3,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 3);
              },
            ),
            const Divider(color: HunorColors.border),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'ÉRTÉKELÉS & ELEMZÉS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: HunorColors.muted,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined, color: HunorColors.red),
              title: const Text('EXCON Értékelő'),
              selected: index == 4,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart_rounded, color: HunorColors.blue),
              title: const Text(
                'Értékelő Műszerfal',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Élő KPI-k és grafikonok (/dashboard)',
                style: TextStyle(fontSize: 11, color: HunorColors.muted),
              ),
              selected: index == 5,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 5);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_rounded, color: HunorColors.success),
              title: const Text(
                'T0 / T1 Űrlapok',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Beavatkozói önértékelés (/t0, /t1)',
                style: TextStyle(fontSize: 11, color: HunorColors.muted),
              ),
              selected: index == 6,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 6);
              },
            ),
            const Divider(color: HunorColors.border),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: HunorColors.muted),
              title: const Text('Profil'),
              selected: index == 7,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 7);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business_rounded, color: HunorColors.muted),
              title: const Text('Szervezetek'),
              selected: index == 8,
              onTap: () {
                Navigator.pop(context);
                setState(() => index = 8);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => index = 5), // Szervezetválasztó
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
        selectedIndex: _bottomNavIndex(index),
        onDestinationSelected: (i) => setState(() => index = _pageIndexFromNav(i)),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Főoldal',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber_rounded),
            label: 'Riasztások',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Naptár',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper_rounded),
            label: 'Hírek',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
