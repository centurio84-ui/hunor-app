import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
  State<MembersPage> createState()=>_MembersPageState();
}
class _MembersPageState extends State<MembersPage>{
  String q='';
  @override Widget build(BuildContext context){final s=context.watch<AppStore>();final list=s.members.where((m)=>m.name.toLowerCase().contains(q.toLowerCase())||m.skills.any((x)=>x.toLowerCase().contains(q.toLowerCase()))).toList();
    return Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Név vagy képesség',border:OutlineInputBorder()))),
      Expanded(child:ListView.builder(itemCount:list.length,itemBuilder:(c,i){final m=list[i];return ListTile(leading:CircleAvatar(child:Text(m.name.isEmpty?'?':m.name[0])),title:Text(m.name),subtitle:Text('${m.rank} • ${m.position}\n${m.status.label}'),isThreeLine:true);}))
    ]);
  }
}