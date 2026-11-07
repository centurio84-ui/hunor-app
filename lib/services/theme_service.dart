import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_error.dart';
import '../models/theme_config.dart';

abstract class ThemeService {
  Future<ThemeContext> getThemeContext(String organizationId);
  Future<List<ThemeCatalogItem>> getCatalog();
  Future<ThemeContext> setMyTheme({
    required String organizationId,
    required String? themeId,
    required int expectedVersion,
  });
  Stream<void> subscribeToThemeSignals({
    required String organizationId,
    required String userId,
  });
  Future<void> unsubscribe();
}

/// Offline és mock teszteléshez használt témamenedzser szolgáltatás.
class MockThemeService implements ThemeService {
  final StreamController<void> _signalsController =
      StreamController<void>.broadcast();
  ThemeContext _context;
  final List<ThemeCatalogItem> _catalog = RescueThemeRegistry.allThemes
      .map(
        (d) => ThemeCatalogItem(
          id: d.id,
          name: d.name,
          category: d.isSeasonal ? 'seasonal' : 'weekday',
          description: d.description,
          primaryColor: d.primaryColor,
        ),
      )
      .toList();

  MockThemeService({ThemeContext? initialContext})
      : _context = initialContext ??
            const ThemeContext(
              contractVersion: 'rp-theme-1',
              organizationId: 'hunor',
              effectiveThemeId: RescueThemeRegistry.defaultThemeId,
              source: 'global',
              organizationVersion: 1,
              allowPersonal: true,
              globalThemeId: RescueThemeRegistry.defaultThemeId,
              globalVersion: 1,
              userVersion: 0,
            );

  void triggerSignal() {
    if (!_signalsController.isClosed) {
      _signalsController.add(null);
    }
  }

  @override
  Future<ThemeContext> getThemeContext(String organizationId) async {
    return _context;
  }

  @override
  Future<List<ThemeCatalogItem>> getCatalog() async {
    return _catalog;
  }

  @override
  Future<ThemeContext> setMyTheme({
    required String organizationId,
    required String? themeId,
    required int expectedVersion,
  }) async {
    if (expectedVersion != _context.userVersion) {
      throw const PreconditionFailedException(
        code: 'PT412',
        message: 'A téma verziója időközben megváltozott a szerveren (PT412).',
      );
    }

    final effective = themeId ??
        _context.organizationThemeId ??
        _context.globalThemeId;

    _context = _context.copyWith(
      effectiveThemeId: effective,
      source: themeId != null
          ? 'user'
          : (_context.organizationThemeId != null ? 'organization' : 'global'),
      userThemeId: themeId,
      userVersion: _context.userVersion + 1,
    );

    triggerSignal();
    return _context;
  }

  @override
  Stream<void> subscribeToThemeSignals({
    required String organizationId,
    required String userId,
  }) {
    return _signalsController.stream;
  }

  @override
  Future<void> unsubscribe() async {
    // Mock esetén nem zárunk csatornát, hogy a tesztek újra feliratkozhassanak
  }

  void dispose() {
    _signalsController.close();
  }
}

/// Valós Supabase RPC és Realtime hívásokat végrehajtó témaszolgáltatás.
class SupabaseThemeService implements ThemeService {
  final String supabaseUrl;
  final String publishableKey;
  final Future<String?> Function() getAccessToken;
  final http.Client _client;
  StreamController<void>? _signalsController;

  SupabaseThemeService({
    String? supabaseUrl,
    String? publishableKey,
    required this.getAccessToken,
    http.Client? client,
  })  : supabaseUrl =
            supabaseUrl ?? 'https://xbcutdkqswfzkubkozng.supabase.co',
        publishableKey = publishableKey ??
            const String.fromEnvironment(
              'SUPABASE_PUBLISHABLE_KEY',
              defaultValue: '',
            ),
        _client = client ?? http.Client();

  Uri _rpcUri(String functionName) {
    final cleanBase = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    return Uri.parse('$cleanBase/rest/v1/rpc/$functionName');
  }

  Future<Map<String, String>> _headers() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (publishableKey.isNotEmpty) 'apikey': publishableKey,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _rpcCall(String functionName, Map<String, dynamic> body) async {
    final uri = _rpcUri(functionName);
    final headers = await _headers();
    final res = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    final status = res.statusCode;
    if (status >= 200 && status < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }

    Map<String, dynamic> errorJson = {};
    try {
      if (res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          errorJson = decoded;
        }
      }
    } catch (_) {}

    final code = errorJson['code']?.toString() ?? 'PT_$status';
    final message =
        errorJson['message']?.toString() ?? 'Supabase RPC hiba: $status';

    if (status == 401 || code == 'PT401') {
      throw UnauthorizedException(code: code, message: message);
    }
    if (status == 403 || code == '42501') {
      throw ForbiddenException(code: code, message: message);
    }
    if (status == 404 || code == 'PT404') {
      throw NotFoundException(code: code, message: message);
    }
    if (status == 412 || code == 'PT412') {
      throw PreconditionFailedException(code: code, message: message);
    }
    if (status == 400 || code == '22023') {
      throw ApiException(statusCode: 400, code: code, message: message);
    }

    throw ApiException(
      statusCode: status,
      code: code,
      message: message,
    );
  }

  @override
  Future<ThemeContext> getThemeContext(String organizationId) async {
    final data = await _rpcCall('rp_get_theme_context', {
      'organization_id': organizationId,
    });
    if (data is Map<String, dynamic>) {
      return ThemeContext.fromJson(data);
    }
    throw const ApiException(
      statusCode: 500,
      code: 'INVALID_RESPONSE',
      message: 'Érvénytelen válasz a témakontextus lekérésekor.',
    );
  }

  @override
  Future<List<ThemeCatalogItem>> getCatalog() async {
    final data = await _rpcCall('rp_get_theme_catalog', {});
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => ThemeCatalogItem.fromJson(item))
          .toList();
    }
    // Fallback helyi katalógusra
    return RescueThemeRegistry.allThemes
        .map(
          (d) => ThemeCatalogItem(
            id: d.id,
            name: d.name,
            category: d.isSeasonal ? 'seasonal' : 'weekday',
            description: d.description,
            primaryColor: d.primaryColor,
          ),
        )
        .toList();
  }

  @override
  Future<ThemeContext> setMyTheme({
    required String organizationId,
    required String? themeId,
    required int expectedVersion,
  }) async {
    final data = await _rpcCall('rp_set_my_theme', {
      'organization_id': organizationId,
      'theme_id': themeId,
      'expected_version': expectedVersion,
    });
    if (data is Map<String, dynamic>) {
      return ThemeContext.fromJson(data);
    }
    return getThemeContext(organizationId);
  }

  @override
  Stream<void> subscribeToThemeSignals({
    required String organizationId,
    required String userId,
  }) {
    _signalsController?.close();
    _signalsController = StreamController<void>.broadcast();

    // Megjegyzés: A valós WebSocket kapcsolatot az aktív Supabase Realtime kliens szolgáltatja.
    // Amikor jelzés érkezik, a csatorna a `_signalsController?.add(null)` hívással invalidál.
    return _signalsController!.stream;
  }

  void triggerSignal() {
    _signalsController?.add(null);
  }

  @override
  Future<void> unsubscribe() async {
    await _signalsController?.close();
    _signalsController = null;
  }
}
