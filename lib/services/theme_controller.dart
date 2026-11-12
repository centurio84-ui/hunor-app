import 'dart:async';
import 'package:flutter/material.dart';
import '../models/api_error.dart';
import '../models/theme_config.dart';
import '../theme/hunor_theme.dart';
import 'theme_service.dart';
import 'theme_vault.dart';

/// ThemeController (ThemeNotifier)
/// Központi témaállapot-kezelő a Rescue Platformhoz.
/// Támogatja az azonnali helyi indulást, a kétirányú Supabase szinkronizációt,
/// a Realtime szerveroldali invalidációs figyelést és a fiókközi adatizolációt.
class ThemeController extends ChangeNotifier {
  final ThemeService themeService;
  final ThemeVault themeVault;

  String _currentThemeId = RescueThemeRegistry.defaultThemeId;
  ThemeContext? _themeContext;
  List<ThemeCatalogItem> _catalog = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<void>? _signalSubscription;

  String? _activeUserId;
  String? _activeOrganizationId;

  ThemeController({
    required this.themeService,
    ThemeVault? themeVault,
  }) : themeVault = themeVault ?? DeviceThemeVault();

  String get currentThemeId => _currentThemeId;
  ThemeData get currentTheme => HunorTheme.themeForId(_currentThemeId);
  RescueThemeDefinition get currentDefinition =>
      RescueThemeRegistry.findById(_currentThemeId);
  ThemeContext? get themeContext => _themeContext;
  List<ThemeCatalogItem> get catalog => List.unmodifiable(_catalog);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSubscribed => _signalSubscription != null;

  /// 1. Indulás: A helyi gyorsítótárban lévő téma azonnali betöltése villanásmentes induláshoz.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final cachedTheme = await themeVault.readTheme();
      if (cachedTheme != null && RescueThemeRegistry.isValidThemeId(cachedTheme)) {
        _currentThemeId = cachedTheme;
      }
      _catalog = await themeService.getCatalog();
    } catch (_) {
      // Helyi olvasási hiba esetén marad az alapértelmezett Alpin téma
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 2. Bejelentkezés vagy szervezetválasztás: szerveres szinkronizáció és Realtime csatorna nyitása.
  Future<void> onUserSignedIn({
    required String userId,
    required String organizationId,
  }) async {
    _activeUserId = userId;
    _activeOrganizationId = organizationId;

    // Betöltjük a felhasználóhoz mentett helyi témát először
    final userCached = await themeVault.readTheme(
      userId: userId,
      organizationId: organizationId,
    );
    if (userCached != null && RescueThemeRegistry.isValidThemeId(userCached)) {
      _currentThemeId = userCached;
      notifyListeners();
    }

    await _fetchServerContextAndSubscribe();
  }

  /// Szervezetváltáskor: a korábbi csatorna leiratkozik, az új szervezet kontextusa töltődik be.
  Future<void> onOrganizationChanged(String organizationId) async {
    if (_activeOrganizationId == organizationId) return;
    _activeOrganizationId = organizationId;

    await _fetchServerContextAndSubscribe();
  }

  Future<void> _fetchServerContextAndSubscribe() async {
    final orgId = _activeOrganizationId;
    final userId = _activeUserId;
    if (orgId == null || userId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Szerveres témakontextus lekérése
      final context = await themeService.getThemeContext(orgId);
      _themeContext = context;

      // 2. Téma alkalmazása és perzisztálása
      _applyEffectiveTheme(context.effectiveThemeId);
      await themeVault.writeTheme(
        _currentThemeId,
        userId: userId,
        organizationId: orgId,
      );

      // 3. Realtime feliratkozás beállítása (korábbi lezárása után)
      await _setupRealtimeSubscription(orgId: orgId, userId: userId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Realtime jelzésfigyelő feliratkozás
  Future<void> _setupRealtimeSubscription({
    required String orgId,
    required String userId,
  }) async {
    await _signalSubscription?.cancel();
    _signalSubscription = null;

    final stream = themeService.subscribeToThemeSignals(
      organizationId: orgId,
      userId: userId,
    );

    _signalSubscription = stream.listen((_) async {
      // Érvénytelenítési jelzés: azonnal frissítjük a szerveres kontextust!
      await resync();
    });
  }

  /// 3. Felhasználói témaváltás (kétirányú szinkronizáció)
  Future<void> setTheme(String? themeId) async {
    final orgId = _activeOrganizationId;
    final userId = _activeUserId;

    // Ha nincs bejelentkezve, csak lokálisan állítjuk
    if (orgId == null || userId == null || _themeContext == null) {
      if (themeId != null && RescueThemeRegistry.isValidThemeId(themeId)) {
        _applyEffectiveTheme(themeId);
        await themeVault.writeTheme(_currentThemeId);
      }
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedContext = await themeService.setMyTheme(
        organizationId: orgId,
        themeId: themeId,
        expectedVersion: _themeContext!.userVersion,
      );
      _themeContext = updatedContext;
      _applyEffectiveTheme(updatedContext.effectiveThemeId);

      await themeVault.writeTheme(
        _currentThemeId,
        userId: userId,
        organizationId: orgId,
      );
    } on PreconditionFailedException catch (_) {
      // PT412 verzióütközés esetén újratöltjük a szerver állapotát
      _errorMessage = 'A szerveren módosult a téma. Frissítés...';
      await resync();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyEffectiveTheme(String themeId) {
    if (RescueThemeRegistry.isValidThemeId(themeId)) {
      _currentThemeId = themeId;
    } else {
      // Ismeretlen témaazonosító esetén a stabil alapértelmezett Alpin sötét témát rendereljük
      _currentThemeId = RescueThemeRegistry.defaultThemeId;
    }
    notifyListeners();
  }

  /// 4. Újracsatlakozás vagy előtérbe visszatéréskor (Reconnect & Resync)
  Future<void> resync() async {
    final orgId = _activeOrganizationId;
    if (orgId == null) return;

    try {
      final context = await themeService.getThemeContext(orgId);
      _themeContext = context;
      _applyEffectiveTheme(context.effectiveThemeId);

      if (_activeUserId != null) {
        await themeVault.writeTheme(
          _currentThemeId,
          userId: _activeUserId!,
          organizationId: orgId,
        );
      }
    } catch (_) {}
  }

  /// 5. Kijelentkezés: Realtime feliratkozás bontása, felhasználói állapot törlése, alapértelmezett téma visszaállítása.
  Future<void> onUserSignedOut() async {
    await _signalSubscription?.cancel();
    _signalSubscription = null;
    await themeService.unsubscribe();

    if (_activeUserId != null) {
      await themeVault.clearForUser(_activeUserId!);
    }

    _activeUserId = null;
    _activeOrganizationId = null;
    _themeContext = null;
    _currentThemeId = RescueThemeRegistry.defaultThemeId;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _signalSubscription?.cancel();
    super.dispose();
  }
}
