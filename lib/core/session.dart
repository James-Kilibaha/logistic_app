import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/user.dart';

/// Kila kitu kinachohifadhiwa kwenye kifaa: kuingia (token + mtumiaji),
/// anwani ya server, kampuni (code + branding), mandhari na lugha.
class Session {
  Session._();

  static late SharedPreferences _prefs;

  /// Anwani iliyowekwa wakati wa kujenga: `--dart-define=API_SERVER=https://api.domain.co.tz` (lazima kwa app ya simu).
  static const String _builtServer = String.fromEnvironment('API_SERVER');

  /// Backend ya development (kompyuta yako). Badilisha kwa `--dart-define=DEV_SERVER=http://192.168.1.200:8000`.
  static const String _devServer = String.fromEnvironment('DEV_SERVER', defaultValue: 'http://localhost:8000');
  // static const String _devServer = String.fromEnvironment('DEV_SERVER', defaultValue: 'http://localhost:8000');

  /// Anwani ya kawaida ya server:
  /// - API_SERVER ikiwekwa wakati wa kujenga -> hiyo (production: web na simu);
  /// - development (`flutter run`, debug) -> DEV_SERVER (kawaida http://localhost:8000);
  /// - web ya production (`flutter build web`) -> domain/IP iliyofungua app (nginx inapeleka /api kwa backend);
  /// - simu bila API_SERVER -> DEV_SERVER.
  static String get defaultServer {
    if (_builtServer.isNotEmpty) return _builtServer;
    if (kDebugMode) return _devServer;
    if (kIsWeb) return Uri.base.origin;
    return _devServer;
  }

  static const _kToken = 'auth.token';
  static const _kRefresh = 'auth.refresh';
  static const _kUser = 'auth.user';
  static const _kPermissions = 'auth.permissions';
  static const _kServer = 'app.server';
  static const _kTheme = 'app.theme';
  static const _kLocale = 'app.locale';
  static const _kLastUsername = 'auth.lastUsername';
  static const _kRemember = 'auth.remember';
  static const _kCompany = 'app.company';
  static const _kBranding = 'app.branding';

  /// App ya kampuni moja (white-label): `--dart-define=COMPANY=ymg` - code ya kampuni haibadilishwi.
  static const String builtCompany = String.fromEnvironment('COMPANY');

  /// "Nikumbuke" imezimwa: token zinakaa kwenye kumbukumbu ya app tu (zinapotea app/tab ikifungwa).
  static String? _memToken;
  static String? _memRefresh;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _memToken = null;
    _memRefresh = null;
    await _migrateOldKeys();
  }

  // ------------------------------------------------------------------ auth

  static String get token => _memToken ?? _prefs.getString(_kToken) ?? '';

  static String get refreshToken => _memRefresh ?? _prefs.getString(_kRefresh) ?? '';

  /// "Nikumbuke": ikiwa imewashwa, mtumiaji anabaki ameingia hata akifunga app (hadi refresh token iishe).
  static bool get rememberMe => _prefs.getBool(_kRemember) ?? true;

  static Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(_kRemember, value);
    if (!value) await _prefs.remove(_kLastUsername);
  }

  static Future<void> _storeTokens(String accessToken, String? refreshToken) async {
    if (rememberMe) {
      _memToken = null;
      _memRefresh = null;
      await _prefs.setString(_kToken, accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) await _prefs.setString(_kRefresh, refreshToken);
    } else {
      _memToken = accessToken;
      if (refreshToken != null && refreshToken.isNotEmpty) _memRefresh = refreshToken;
      await _prefs.remove(_kToken);
      await _prefs.remove(_kRefresh);
    }
  }

  /// Kuna token halali, au refresh token halali (app itapata token mpya yenyewe).
  static bool get isLoggedIn =>
      (token.isNotEmpty && !_isExpired(token)) || (refreshToken.isNotEmpty && !_isExpired(refreshToken));

  /// Token inakaribia kuisha (au imeisha) - ni wakati wa kuomba mpya.
  static bool get tokenNeedsRefresh =>
      refreshToken.isNotEmpty && (token.isEmpty || _isExpired(token, margin: const Duration(seconds: 60)));

  static AppUser? get user {
    final raw = _prefs.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static String get lastUsername => _prefs.getString(_kLastUsername) ?? '';

  static Future<void> saveLogin(String accessToken, Map<String, dynamic> user, {String? refreshToken}) async {
    await _storeTokens(accessToken, refreshToken);
    await _prefs.setString(_kUser, jsonEncode(user));
    if (rememberMe) {
      await _prefs.setString(_kLastUsername, (user['username'] ?? '').toString());
    } else {
      await _prefs.remove(_kLastUsername);
    }
  }

  // ------------------------------------------- super admin anaangalia kampuni (kusoma tu)
  static const _kViewAs = 'platform.viewAs';

  /// Jina la super admin anayeangalia kampuni sasa ('' = kuingia kwa kawaida).
  static String get viewAs => _prefs.getString(_kViewAs) ?? '';

  /// Kuingia kwa token ya "kuangalia tu" (haigusi jina la mwisho la mtumiaji wala refresh token).
  static Future<void> saveViewAsLogin(String accessToken, Map<String, dynamic> user, String viewer) async {
    await _storeTokens(accessToken, '');
    await _prefs.setString(_kUser, jsonEncode(user));
    await _prefs.setString(_kViewAs, viewer);
  }

  /// Ruhusa za mtumiaji (zinahifadhiwa ili menyu zionekane hata kabla ya kuzipakua upya).
  static List<dynamic> get permissionsJson {
    final raw = _prefs.getString(_kPermissions);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  /// Token mpya kutoka /auth/refresh.
  static Future<void> saveTokens(String accessToken, String refreshToken) => _storeTokens(accessToken, refreshToken);

  static Future<void> savePermissions(List<dynamic> json) => _prefs.setString(_kPermissions, jsonEncode(json));

  /// Inafuta taarifa za kuingia tu: server, lugha na mandhari vinabaki.
  static Future<void> clearLogin() async {
    _memToken = null;
    _memRefresh = null;
    await _prefs.remove(_kToken);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kUser);
    await _prefs.remove(_kPermissions);
    await _prefs.remove(_kViewAs);
  }

  /// JWT: `exp` iko kwenye sehemu ya pili (payload).
  static bool _isExpired(String jwt, {Duration margin = Duration.zero}) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! num) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().add(margin).isAfter(expiry);
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------- super admin

  /// Token ya super admin (wewe - /super-admin). Haichanganywi na token ya mtumiaji wa kampuni.
  static const _kPlatformToken = 'platform.token';
  static const _kPlatformAdmin = 'platform.admin';

  static String get platformToken {
    final t = _prefs.getString(_kPlatformToken) ?? '';
    return t.isNotEmpty && _isExpired(t) ? '' : t;
  }

  static Map<String, dynamic>? get platformAdmin {
    final raw = _prefs.getString(_kPlatformAdmin);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePlatformLogin(String token, Map<String, dynamic> admin) async {
    await _prefs.setString(_kPlatformToken, token);
    await _prefs.setString(_kPlatformAdmin, jsonEncode(admin));
  }

  static Future<void> clearPlatformLogin() async {
    await _prefs.remove(_kPlatformToken);
    await _prefs.remove(_kPlatformAdmin);
  }

  // --------------------------------------------------------------- kampuni

  /// Code ya kampuni (slug) inayotumwa kama `X-Company`. Web kwenye domain ya kampuni haihitaji
  /// (server inaitambua kwa domain) - lakini ikishajulikana inahifadhiwa pia.
  static String get companySlug {
    if (builtCompany.isNotEmpty) return builtCompany;
    return _prefs.getString(_kCompany) ?? '';
  }

  static bool get companyLocked => builtCompany.isNotEmpty;

  static Future<void> saveCompany(String slug) async {
    final v = slug.trim().toLowerCase();
    if (v.isEmpty) {
      await _prefs.remove(_kCompany);
    } else {
      await _prefs.setString(_kCompany, v);
    }
  }

  /// Branding ya mwisho (jina, logo, rangi) - inaonyeshwa papo hapo app ikifunguka, kabla ya kupakua mpya.
  static Map<String, dynamic>? get brandingJson {
    final raw = _prefs.getString(_kBranding);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveBranding(Map<String, dynamic>? json) async {
    if (json == null) {
      await _prefs.remove(_kBranding);
    } else {
      await _prefs.setString(_kBranding, jsonEncode(json));
    }
  }

  // ---------------------------------------------------------------- server

  /// Mfano: `http://192.168.1.200:8000` (bila `/api`).
  static String get server {
    final saved = _prefs.getString(_kServer);
    if (saved == null || saved.isEmpty) return defaultServer;
    // Web ya production iliyofunguliwa kwa https haiwezi kuita server ya http (browser inazuia "mixed content"):
    // mf. anwani ya IP iliyohifadhiwa kabla ya domain kuwekwa. Tumia domain iliyofungua app.
    if (kIsWeb && !kDebugMode && Uri.base.scheme == 'https' && saved.startsWith('http://')) return defaultServer;
    return saved;
  }

  static String get apiBase => '$server/api/';

  /// Anwani kamili ya njia inayotoka kwa server (mf. logoUrl `/api/public/branding/logo?...`).
  static String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$server${path.startsWith('/') ? '' : '/'}$path';
  }

  static Future<void> saveServer(String value) => _prefs.setString(_kServer, normalizeServer(value));

  /// Inakubali "192.168.1.200:8000", "http://x:8000/", "https://api.domain.co.tz" ...
  static String normalizeServer(String value) {
    var v = value.trim();
    if (v.isEmpty) return defaultServer;
    if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'http://$v';
    v = v.replaceAll(RegExp(r'/+$'), '');
    if (v.endsWith('/api')) v = v.substring(0, v.length - 4);
    return v;
  }

  /// Picha ya bidhaa iliyohifadhiwa kwenye server.
  static String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    // Picha si za umma tena: tokeni inaongezwa (img tag haiwezi kutuma header ya Authorization).
    final t = token;
    return '${apiBase}product/open-images/$path${t.isEmpty ? '' : '?t=${Uri.encodeQueryComponent(t)}'}';
  }

  // ------------------------------------------------------- theme & locale

  static ThemeMode get themeMode => switch (_prefs.getString(_kTheme)) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };

  static Future<void> saveThemeMode(ThemeMode mode) => _prefs.setString(_kTheme, mode.name);

  static Locale get locale {
    final saved = _prefs.getString(_kLocale) ?? 'sw_TZ';
    final parts = saved.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return const Locale('sw', 'TZ');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  static Future<void> saveLocale(Locale locale) {
    final country = locale.countryCode;
    final value = (country == null || country.isEmpty) ? locale.languageCode : '${locale.languageCode}_$country';
    return _prefs.setString(_kLocale, value);
  }

  /// App ya zamani ilihifadhi server kama `serverHost` + `serverPort`.
  static Future<void> _migrateOldKeys() async {
    final oldHost = _prefs.getString('serverHost');
    if (oldHost != null && !_prefs.containsKey(_kServer)) {
      final port = _prefs.getInt('serverPort') ?? 8000;
      await saveServer('$oldHost:$port');
    }
    final oldLocale = _prefs.getString('locale');
    if (oldLocale != null && !_prefs.containsKey(_kLocale)) {
      await _prefs.setString(_kLocale, oldLocale);
    }
  }
}
