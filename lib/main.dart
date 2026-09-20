import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'services/app_store.dart';
import 'views/app_shell.dart';
import 'views/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStore()..initialize(),
      child: const HunorApp(),
    ),
  );
}

class HunorApp extends StatelessWidget {
  const HunorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUNOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Consumer<AppStore>(
        builder: (context, store, _) {
          if (!store.initialized) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return store.isAuthenticated ? const AppShell() : const LoginPage();
        },
      ),
    );
  }
}
