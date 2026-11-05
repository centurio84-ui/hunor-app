import 'package:flutter/foundation.dart';
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

  // Kiadási (Release) védelmi kapu: production kiadásban tilos a mock vagy az engedélyezetlen API mód
  if (kReleaseMode && apiMode == 'mock') {
    throw StateError(
      'BIZTONSÁGI HIBA: Production Release build nem futtatható Mock API módban! '
      'Állítsd be a jóváhagyott éles RESCUE_API_MODE és RESCUE_API_BASE_URL környezeti változókat.',
    );
  }

  if (!['mock', 'staging', 'production'].contains(apiMode)) {
    throw StateError('Invalid API mode: $apiMode');
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
    final themeController = Provider.of<ThemeController?>(context);
    final theme = themeController?.currentTheme ?? HunorTheme.dark;

    return MaterialApp(
      title: 'Rescue Platform',
      debugShowCheckedModeBanner: false,
      theme: theme,
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
