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
const String apiBaseUrl = String.fromEnvironment('RESCUE_API_BASE_URL', defaultValue: '');

/// Visszaadja az érvényes, jóváhagyott [RescuePlatformApi] példányt az [apiMode] és [apiBaseUrl] alapján.
/// Production módban kizárólag érvényes, jóváhagyott production API-adapter használható,
/// mock vagy nem jóváhagyott adapter/fallback esetén azonnal [StateError] kivételt dob.
RescuePlatformApi createConfiguredApi({
  required String mode,
  required String baseUrl,
  bool isRelease = kReleaseMode,
}) {
  if (isRelease && mode == 'mock') {
    throw StateError(
      'BIZTONSÁGI HIBA: Production Release build nem futtatható Mock API módban! '
      'Állítsd be a jóváhagyott éles RESCUE_API_MODE és RESCUE_API_BASE_URL környezeti változókat.',
    );
  }

  if (mode == 'mock') {
    return MockRescuePlatformApi();
  }

  if (mode == 'staging') {
    final effectiveUrl = baseUrl.isEmpty ? stagingBase : baseUrl;
    return StagingApi(baseUrl: effectiveUrl);
  }

  if (mode == 'production') {
    // Production mód: kizárólag jóváhagyott production API adapter használható.
    // Mock vagy staging adapter fallback szigorúan tilos!
    if (baseUrl.isEmpty) {
      throw StateError(
        'BIZTONSÁGI HIBA: Production API módban a RESCUE_API_BASE_URL nem lehet üres! '
        'A production kiadás nem indulhat el konfigurálatlan végponttal.',
      );
    }
    throw StateError(
      'BIZTONSÁGI HIBA: A hitelesített Production API adapter implementációja és éles jóváhagyása még nem történt meg. '
      'Mock vagy teszt adapter fallback production módban szigorúan tilos! A futás biztonságosan leállt.',
    );
  }

  throw StateError('Invalid API mode: $mode');
}

/// Visszaadja az API módnak és kiválasztott API adapternek megfelelő [ThemeService] szolgáltatást.
ThemeService createConfiguredThemeService({
  required String mode,
  required RescuePlatformApi api,
}) {
  if (mode == 'staging' && api is StagingApi) {
    return SupabaseThemeService(
      getAccessToken: () async => api.accessToken,
    );
  }

  if (mode == 'production') {
    throw StateError(
      'BIZTONSÁGI HIBA: Production ThemeService adapter nincs konfigurálva vagy jóváhagyva.',
    );
  }

  return MockThemeService();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final RescuePlatformApi selectedApi = createConfiguredApi(
    mode: apiMode,
    baseUrl: apiBaseUrl,
    isRelease: kReleaseMode,
  );

  final ThemeService themeService = createConfiguredThemeService(
    mode: apiMode,
    api: selectedApi,
  );

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
