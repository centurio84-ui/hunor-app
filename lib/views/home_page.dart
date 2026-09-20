import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override Widget build(BuildContext context) {
    final s=context.watch<AppStore>();
    final next=s.events.where((e)=>e.date.isAfter(DateTime.now())).firstOrNull;
    return RefreshIndicator(onRefresh:s.loadData,child:ListView(padding:const EdgeInsets.all(16),children:[
      Text('Üdv, ${s.currentUser?.name ?? ''}!',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:16),
      Row(children:[
        Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[const Icon(Icons.people),Text('${s.members.length}',style:TextStyle(fontSize:28)),const Text('Tagok')])))),
        const SizedBox(width:10),
        Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[const Icon(Icons.notifications),Text('${s.alerts.where((a)=>a.status=="active").length}',style:TextStyle(fontSize:28)),const Text('Aktív riasztás')])))),
      ]),
      const SizedBox(height:16),
      Card(child:ListTile(leading:const Icon(Icons.calendar_month),title:const Text('Következő esemény'),subtitle:Text(next==null?'Nincs közelgő esemény':'${next.title}\n${next.location}'))),
    ]));
  }
}