import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override Widget build(BuildContext context) {
    final s=context.watch<AppStore>();
    return RefreshIndicator(onRefresh:s.loadData,child:ListView.builder(
      itemCount:s.alerts.length,physics:const AlwaysScrollableScrollPhysics(),
      itemBuilder:(c,i){final a=s.alerts[i];final r=s.alertResponses[a.id];return Card(margin:const EdgeInsets.all(8),child:ListTile(
        leading:Icon(a.type=='alert'?Icons.warning:Icons.notifications_active),title:Text(a.title),
        subtitle:Text('${a.typeLabel}\n${a.message}'),isThreeLine:true,
        trailing:r==null?const Icon(Icons.chevron_right):Icon(r=='available'?Icons.check_circle:Icons.cancel),
        onTap:()=>showModalBottomSheet(context:c,builder:(_)=>Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(a.typeLabel,style:Theme.of(c).textTheme.labelLarge),Text(a.title,style:Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height:12),Text(a.message),const SizedBox(height:18),
          FilledButton(onPressed:(){Navigator.pop(c);s.respondToAlert(a.id,true);},child:const Text('Elérhető vagyok')),
          OutlinedButton(onPressed:(){Navigator.pop(c);s.respondToAlert(a.id,false);},child:const Text('Nem vagyok elérhető')),
        ]))));},
    ));
  }
}