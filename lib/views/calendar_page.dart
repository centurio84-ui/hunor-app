import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});
  @override Widget build(BuildContext context) {
    final s=context.watch<AppStore>();
    return RefreshIndicator(onRefresh:s.loadData,child:ListView.builder(
      itemCount:s.events.length,physics:const AlwaysScrollableScrollPhysics(),
      itemBuilder:(c,i){final e=s.events[i];final r=s.eventResponses[e.id];return Card(margin:const EdgeInsets.all(8),child:ListTile(
        leading:const Icon(Icons.calendar_month),title:Text(e.title),subtitle:Text('${e.location}\n${e.date}'),isThreeLine:true,
        onTap:()=>showModalBottomSheet(context:c,builder:(_)=>Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(e.title,style:Theme.of(c).textTheme.headlineSmall),Text(e.details),const SizedBox(height:16),
          FilledButton(onPressed:(){Navigator.pop(c);s.respondToEvent(e.id,true);},child:Text(r=='going'?'Részt veszek ✓':'Részt veszek')),
          OutlinedButton(onPressed:(){Navigator.pop(c);s.respondToEvent(e.id,false);},child:Text(r=='not_going'?'Nem veszek részt ✓':'Nem veszek részt')),
        ]))));},
    ));
  }
}