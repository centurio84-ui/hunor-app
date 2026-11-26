import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'features/event_quiz/event_quiz_admin_screen.dart';
import 'features/event_quiz/event_quiz_guest_screen.dart';
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

  /// Resolves `/quiz?event=<slug>`, `/#/quiz?event=<slug>`, or standard `/quiz` (no `event` param).
  static ({bool matched, String? slug}) _resolveQuizRoute([String? routeName]) {
    if (routeName != null && routeName.isNotEmpty) {
      final parsed = Uri.tryParse(routeName);
      if (parsed != null &&
          (parsed.path == '/quiz' ||
              parsed.path.endsWith('/quiz') ||
              parsed.queryParameters['mode'] == 'quiz')) {
        final slug = parsed.queryParameters['event']?.trim();
        return (
          matched: true,
          slug: (slug != null && slug.isNotEmpty) ? slug : null,
        );
      }
    }
    if (!kIsWeb) return (matched: false, slug: null);
    final base = Uri.base;
    if (base.path == '/quiz' ||
        base.path.endsWith('/quiz') ||
        base.path.endsWith('/quiz/') ||
        base.queryParameters['mode'] == 'quiz') {
      final directEvent = base.queryParameters['event']?.trim();
      return (
        matched: true,
        slug: (directEvent != null && directEvent.isNotEmpty)
            ? directEvent
            : null,
      );
    }
    final frag = base.fragment;
    if (frag.isNotEmpty) {
      final fragUri =
          Uri.tryParse(frag.startsWith('/') ? frag : '/$frag');
      if (fragUri != null &&
          (fragUri.path == '/quiz' ||
              fragUri.path.endsWith('/quiz') ||
              fragUri.queryParameters['mode'] == 'quiz')) {
        final fSlug = fragUri.queryParameters['event']?.trim();
        return (
          matched: true,
          slug: (fSlug != null && fSlug.isNotEmpty) ? fSlug : null,
        );
      }
    }
    return (matched: false, slug: null);
  }

  static bool _isQuizEventsAdminUrl([String? routeName]) {
    if (routeName != null && routeName.isNotEmpty) {
      if (routeName.startsWith('/quiz-events')) return true;
      final parsed = Uri.tryParse(routeName);
      if (parsed != null &&
          (parsed.path == '/quiz-events' ||
              parsed.path.endsWith('/quiz-events') ||
              parsed.queryParameters['mode'] == 'quiz_admin')) {
        return true;
      }
    }
    if (!kIsWeb) return false;
    final base = Uri.base;
    if (base.queryParameters['mode'] == 'quiz_admin' ||
        base.path.endsWith('/quiz-events')) {
      return true;
    }
    if (base.fragment.startsWith('/quiz-events') ||
        base.fragment.startsWith('quiz-events')) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController?>(context);
    final theme = themeController?.currentTheme ?? HunorTheme.dark;
    final initialQuiz = _resolveQuizRoute();
    final initialQuizAdmin = _isQuizEventsAdminUrl();

    return MaterialApp(
      title: 'MAD Tech Rescue Platform',
      debugShowCheckedModeBanner: false,
      theme: theme,
      onGenerateRoute: (settings) {
        final quizRoute = _resolveQuizRoute(settings.name);
        if (quizRoute.matched) {
          // Guest bypass: load EventQuizGuestScreen directly without requiring login!
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => EventQuizGuestScreen(eventSlug: quizRoute.slug),
          );
        }
        if (_isQuizEventsAdminUrl(settings.name)) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const EventQuizAdminScreen(
              onReturnToPortal: _returnToPortal,
            ),
          );
        }
        return null;
      },
      routes: {
        '/planning': (context) => const ExercisePlanningScreen(),
        '/quiz': (context) => const EventQuizGuestScreen(),
        '/quiz-events': (context) =>
            const EventQuizAdminScreen(onReturnToPortal: _returnToPortal),
        '/excon': (context) => const Scaffold(body: ExconScreen()),
        '/dashboard': (context) => const Scaffold(body: ExconDashboardScreen()),
        '/t0': (context) => const Scaffold(body: T0Screen()),
        '/t1': (context) => const Scaffold(body: T1Screen()),
      },
      home: initialQuiz.matched
          ? EventQuizGuestScreen(eventSlug: initialQuiz.slug)
          : Consumer<AppStore>(
              builder: (context, store, _) {
                if (!store.initialized) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: HunorColors.red),
                    ),
                  );
                }
                if (initialQuizAdmin) {
                  return const EventQuizAdminScreen(
                    onReturnToPortal: _returnToPortal,
                  );
                }
                if (portalPlanning) {
                  return const ExercisePlanningScreen(
                    onReturnToPortal: _returnToPortal,
                  );
                }
                return store.isAuthenticated
                    ? const AppShell()
                    : const LoginPage();
              },
            ),
    );
  }
}
