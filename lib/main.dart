import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/mock_rescue_platform_api.dart';
import 'services/app_store.dart';
import 'theme/hunor_theme.dart';
import 'views/app_shell.dart';
import 'views/login_page.dart';

const bool useMockApi = bool.fromEnvironment('USE_MOCK_API', defaultValue: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final mockApi = MockRescuePlatformApi();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStore(api: mockApi)..initialize(),
      child: const HunorApp(),
    ),
  );
}

class HunorApp extends StatelessWidget {
  const HunorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rescue Platform',
      debugShowCheckedModeBanner: false,
      theme: HunorTheme.dark,
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
