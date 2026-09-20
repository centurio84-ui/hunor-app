import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override Widget build(BuildContext context){final s=context.watch<AppStore>();final u=s.currentUser;if(u==null)return const Center(child:CircularProgressIndicator());
    return ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(u.name),subtitle:Text('${u.rank}\n${u.position}\n${u.workplace}'))),
      Card(child:ListTile(title:const Text('Állapot'),subtitle:Text(u.status.label))),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:8,children:[for(final x in u.skills)Chip(label:Text(x))]))),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:s.signOut,icon:const Icon(Icons.logout),label:const Text('Kijelentkezés')),
    ]);
  }
}