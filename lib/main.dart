import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'services/app_store.dart';
import 'services/navigation_controller.dart';
import 'services/push_notification_service.dart';
import 'theme/hunor_theme.dart';
import 'views/app_shell.dart';
import 'views/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStore()..initialize()),
        ChangeNotifierProvider(create: (_) => NavigationController(Supabase.instance.client)),
      ],
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
      theme: HunorTheme.dark,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(settings: settings,
        builder: (context) => Consumer<AppStore>(builder: (context, store, _) =>
          store.isAuthenticated ? AppShell(initialRoute: settings.name ?? '/') : const LoginPage())),
      home: Consumer<AppStore>(
        builder: (context, store, _) {
          if (!store.initialized) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: HunorColors.red),
              ),
            );
          }
          return store.isAuthenticated ? const AppShell() : const LoginPage();
        },
      ),
    );
  }
}
