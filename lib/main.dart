import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/mock_rescue_platform_api.dart';
import 'api/staging_api.dart';
import 'api/rescue_platform_api.dart';
import 'services/app_store.dart';
import 'services/theme_controller.dart';
import 'services/theme_service.dart';
import 'services/theme_vault.dart';
import 'theme/hunor_theme.dart';
import 'views/app_shell.dart';
import 'views/login_page.dart';

const String apiMode = String.fromEnvironment('RESCUE_API_MODE', defaultValue: 'mock');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!['mock', 'staging'].contains(apiMode)) {
    throw StateError('Invalid API mode');
  }

  final RescuePlatformApi selectedApi = apiMode == 'staging'
      ? StagingApi(baseUrl: const String.fromEnvironment('RESCUE_API_BASE_URL', defaultValue: stagingBase))
      : MockRescuePlatformApi();

  final ThemeService themeService = apiMode == 'staging' && selectedApi is StagingApi
      ? SupabaseThemeService(
          getAccessToken: () async => selectedApi.accessToken,
        )
      : MockThemeService();

  final themeController = ThemeController(
    themeService: themeService,
    themeVault: DeviceThemeVault(),
  );

  // Azonnali, flash-mentes helyi témainicializálás
  await themeController.initialize();

  final appStore = AppStore(
    api: selectedApi,
    themeController: themeController,
  )..initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<AppStore>.value(value: appStore),
      ],
      child: const HunorApp(),
    ),
  );
}

class HunorApp extends StatelessWidget {
  const HunorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: 'Rescue Platform',
      debugShowCheckedModeBanner: false,
      theme: themeController.currentTheme,
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
