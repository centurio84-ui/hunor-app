import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'features/planning/exercise_planning_screen.dart';
import 'api/mock_rescue_platform_api.dart';
import 'api/staging_api.dart';
import 'api/supabase_rescue_platform_api.dart';
import 'api/rescue_platform_api.dart';
import 'services/app_store.dart';
import 'services/local_notification_service.dart';
import 'services/theme_controller.dart';
import 'services/theme_service.dart';
import 'services/theme_vault.dart';
import 'theme/hunor_theme.dart';
import 'views/app_shell.dart';
import 'views/excon_dashboard_screen.dart';
import 'views/excon_screen.dart';
import 'views/login_page.dart';
import 'views/t0_screen.dart';
import 'views/t1_screen.dart';

const String apiMode = String.fromEnvironment('RESCUE_API_MODE', defaultValue: 'supabase');
const String apiBaseUrl = String.fromEnvironment('RESCUE_API_BASE_URL', defaultValue: '');

/// Visszaadja az érvényes, jóváhagyott [RescuePlatformApi] példányt az [apiMode] és [apiBaseUrl] alapján.
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

  if (mode == 'supabase') {
    return SupabaseRescuePlatformApi();
  }

  if (mode == 'production') {
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

  if (mode == 'supabase' && api is SupabaseRescuePlatformApi) {
    return SupabaseThemeService(
      getAccessToken: () async => api.client.auth.currentSession?.accessToken,
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
  await LocalNotificationService.instance.initialize();

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
    );
  } catch (_) {
    // Ha már inicializálva van vagy teszt/offline környezetben fut
  }

  // Tiszta webes URL stratégia (eltávolítja a '#' hash jelet a webes URL-ből, pl. /excon, /dashboard)
  usePathUrlStrategy();

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
  const HunorApp({
    super.key,
    this.portalPlanning = kIsWeb && const bool.fromEnvironment('HUNOR_PORTAL_PLANNING'),
  });

  final bool portalPlanning;

  static void _returnToPortal() {
    launchUrl(Uri.base.resolve('/#home'), webOnlyWindowName: '_self');
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController?>(context);
    final theme = themeController?.currentTheme ?? HunorTheme.dark;

    return MaterialApp(
      title: 'MAD Tech Rescue Platform',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routes: {
        '/planning': (context) => const ExercisePlanningScreen(),
        '/excon': (context) => const Scaffold(body: ExconScreen()),
        '/dashboard': (context) => const Scaffold(body: ExconDashboardScreen()),
        '/t0': (context) => const Scaffold(body: T0Screen()),
        '/t1': (context) => const Scaffold(body: T1Screen()),
      },
      home: Consumer<AppStore>(
        builder: (context, store, _) {
          if (!store.initialized) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: HunorColors.red),
              ),
            );
          }
          if (portalPlanning) {
            return const ExercisePlanningScreen(onReturnToPortal: _returnToPortal);
          }
          return store.isAuthenticated ? const AppShell() : const LoginPage();
        },
      ),
    );
  }
}
