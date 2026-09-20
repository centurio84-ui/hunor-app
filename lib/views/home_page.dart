import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  String _date(DateTime d) => '\${d.year}.\${d.month.toString().padLeft(2,'0')}.\${d.day.toString().padLeft(2,'0')} \${d.hour.toString().padLeft(2,'0')}:\${d.minute.toString().padLeft(2,'0')}';

  @override Widget build(BuildContext context) {
    final s=context.watch<AppStore>(); final now=DateTime.now();
    final next=s.events.where((e)=>e.date.isAfter(now)).firstOrNull;
    final active=s.alerts.where((a)=>a.status=='active').length; final u=s.currentUser;
    return RefreshIndicator(onRefresh:s.loadData,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,8,16,24),children:[
      Text('Üdv, \${u?.name ?? 'HUNOR tag'}!',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:4), const Text('Műveleti áttekintés',style:TextStyle(color:HunorColors.muted)), const SizedBox(height:18),
      Card(color:HunorColors.redDark,child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[
        Container(width:52,height:52,decoration:BoxDecoration(color:Colors.white.withOpacity(.12),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.shield_outlined,size:30)),
        const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('HUNOR',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:3),
          Text(u?.status.label ?? 'Állapot betöltése...',style:const TextStyle(color:Colors.white70)),
        ])),const Icon(Icons.chevron_right,color:Colors.white70),
      ]))),
      const SizedBox(height:10),Row(children:[
        Expanded(child:_StatCard(icon:Icons.groups_2_outlined,value:'\${s.members.length}',label:'Állomány')),
        const SizedBox(width:10),
        Expanded(child:_StatCard(icon:Icons.warning_amber_rounded,value:'$active',label:'Aktív riasztás',accent:active>0?HunorColors.red:HunorColors.success)),
      ]),
      const SizedBox(height:14),Text('Következő esemény',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:6),
      if(next==null) const Card(child:Padding(padding:EdgeInsets.all(18),child:Row(children:[Icon(Icons.event_available_outlined,color:HunorColors.success),SizedBox(width:12),Text('Nincs közelgő esemény',style:TextStyle(fontWeight:FontWeight.w600))])))
      else Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
        Container(width:54,height:64,decoration:BoxDecoration(color:HunorColors.exercise.withOpacity(.15),borderRadius:BorderRadius.circular(12)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text('\${next.date.day}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:HunorColors.exercise)),Text('\${next.date.month}. hó',style:const TextStyle(fontSize:11,color:HunorColors.muted)),
        ])),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(next.title,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:5),Text(_date(next.date),style:const TextStyle(color:HunorColors.muted)),
          if(next.location.isNotEmpty) ...[const SizedBox(height:3),Text(next.location,style:const TextStyle(color:HunorColors.muted))],
        ])),
      ]))),
      const SizedBox(height:14),Text('Gyors áttekintés',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:6),
      Card(child:Column(children:[
        _QuickRow(Icons.notifications_active_outlined,'Riasztások','\${s.alerts.length} bejegyzés'),const Divider(height:1),
        _QuickRow(Icons.calendar_month_outlined,'Naptár','\${s.events.length} esemény'),const Divider(height:1),
        _QuickRow(Icons.manage_accounts_outlined,'Saját profil',u?.position ?? 'Profil'),
      ])),
    ]));
  }
}
class _StatCard extends StatelessWidget {
  final IconData icon; final String value,label; final Color accent;
  const _StatCard({required this.icon,required this.value,required this.label,this.accent=HunorColors.text});
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
    Icon(icon,color:accent,size:26),const SizedBox(width:12),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(value,style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:accent)),Text(label,style:const TextStyle(color:HunorColors.muted,fontSize:12))
    ])
  ])));
}
class _QuickRow extends StatelessWidget {
  final IconData icon; final String title,value;
  const _QuickRow(this.icon,this.title,this.value);
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),child:Row(children:[
    Icon(icon,color:HunorColors.muted),const SizedBox(width:12),Expanded(child:Text(title,style:const TextStyle(fontWeight:FontWeight.w700))),Text(value,style:const TextStyle(color:HunorColors.muted))
  ]));
}