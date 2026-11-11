import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart' show Trans;
import 'package:http/http.dart' as http;

import '../../core/api/api_client.dart';
import '../../core/session.dart';

/// Mawasiliano ya super admin na backend (`/api/platform/...`).
///
/// Ni tofauti na [Api] ya kampuni: inatumia token ya super admin ([Session.platformToken]) na haitumi
/// `X-Company`, kwa hiyo akaunti yako haichanganywi na data ya kampuni yoyote.
class PlatformApi {
  PlatformApi._();

  static const Duration _timeout = Duration(seconds: 40);

  /// Token imeisha / si halali (401): ukurasa unarudi kwenye kuingia.
  static VoidCallback? onUnauthorized;

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${Session.apiBase}platform/$clean');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      for (final e in query.entries)
        if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value.toString(),
    });
  }

  static Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (Session.platformToken.isNotEmpty) 'Authorization': 'Bearer ${Session.platformToken}',
      };

  static Future<dynamic> _run(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(null, 'errTimeout'.tr);
    } catch (e) {
      throw ApiException(null, 'errNoServer'.tr);
    }
    final text = utf8.decode(res.bodyBytes);
    dynamic body;
    try {
      body = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      body = text;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401) onUnauthorized?.call();
    throw ApiException(res.statusCode, _message(res.statusCode, body));
  }

  static String _message(int status, dynamic body) {
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        return first is Map ? (first['msg'] ?? first).toString() : first.toString();
      }
      return detail.toString();
    }
    if (status == 401) return 'errSession'.tr;
    if (status == 404) return 'errNotFound'.tr;
    if (status >= 500) return 'errServer'.tr;
    return '${'errUnknown'.tr} ($status)';
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => http.get(_uri(path, query), headers: _headers(json: false)));

  static Future<dynamic> post(String path, [Object? body]) =>
      _run(() => http.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? const {})));

  static Future<dynamic> put(String path, [Object? body]) =>
      _run(() => http.put(_uri(path), headers: _headers(), body: jsonEncode(body ?? const {})));

  static Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _run(() => http.delete(_uri(path, query), headers: _headers(json: false)));

  /// Faili (PDF) - mf. risiti ya malipo ya subscription.
  static Future<Uint8List> getBytes(String path) async {
    final http.Response res;
    try {
      res = await http.get(_uri(path), headers: _headers(json: false)).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(null, 'errTimeout'.tr);
    } catch (e) {
      throw ApiException(null, 'errNoServer'.tr);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    if (res.statusCode == 401) onUnauthorized?.call();
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }
    throw ApiException(res.statusCode, _message(res.statusCode, body));
  }

  /// Faili moja (multipart, sehemu "file") - logo ya kampuni.
  static Future<dynamic> upload(String path, Uint8List bytes, String fileName) {
    return _run(() async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers(json: false))
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      return http.Response.fromStream(await request.send());
    });
  }

  // ------------------------------------------------------------------ kuingia

  /// Inarudisha `challenge` kama akaunti ina 2FA (hatua ya pili: [login2fa]); vinginevyo null (umeingia).
  static Future<String?> login(String username, String password) async {
    final body = await post('login', {'username': username.trim(), 'password': password});
    if (body is Map && body['twoFactorRequired'] == true) return (body['challenge'] ?? '').toString();
    await _saveLogin(body);
    return null;
  }

  /// Hatua ya pili: code ya app ya Authenticator (au code ya dharura XXXX-XXXX).
  static Future<void> login2fa(String challenge, String code) async {
    await _saveLogin(await post('login/2fa', {'challenge': challenge, 'code': code.trim()}));
  }

  static Future<void> _saveLogin(dynamic body) async {
    if (body is! Map || (body['access_token'] ?? '').toString().isEmpty) throw ApiException(null, 'errUnknown'.tr);
    await Session.savePlatformLogin(
      body['access_token'].toString(),
      Map<String, dynamic>.from((body['admin'] as Map?) ?? const {}),
    );
  }

  // ------------------------------------------------------------------ uthibitisho wa hatua mbili (2FA)

  static Future<Map<String, dynamic>> twoFactor() async => _map(await get('me/2fa'));

  /// {secret, uri} - uri ni QR ya kuskani kwenye app ya Authenticator.
  static Future<Map<String, dynamic>> twoFactorSetup() async => _map(await post('me/2fa/setup'));

  /// Inarudisha code 10 za dharura (zionyeshwe mara moja tu).
  static Future<List<String>> twoFactorEnable(String code) async =>
      _codes(await post('me/2fa/enable', {'code': code.trim()}));

  static Future<void> twoFactorDisable(String password, String code) =>
      post('me/2fa/disable', {'password': password, 'code': code.trim()});

  static Future<List<String>> twoFactorNewRecovery(String password, String code) async =>
      _codes(await post('me/2fa/recovery', {'password': password, 'code': code.trim()}));

  static Future<void> resetTwoFactor(String adminId) => post('admins/$adminId/reset-2fa');

  /// Kusasisha taarifa za akaunti iliyoingia (mf. baada ya kuwasha 2FA).
  static Future<void> refreshMe() async {
    final body = await get('me');
    if (body is Map && Session.platformToken.isNotEmpty) {
      await Session.savePlatformLogin(Session.platformToken, Map<String, dynamic>.from(body));
    }
  }

  static Map<String, dynamic> _map(dynamic body) =>
      body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

  static List<String> _codes(dynamic body) =>
      body is Map && body['recoveryCodes'] is List ? (body['recoveryCodes'] as List).map((e) => '$e').toList() : [];

  static Future<void> logout() => Session.clearPlatformLogin();

  /// Umesahau nywila, hatua ya 1: code inatumwa kwa SMS/email. Inarudisha {resetToken, sentTo, username}.
  static Future<Map<String, dynamic>> forgot(String username) async {
    final body = await post('forgot', {'username': username.trim()});
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  /// Hatua ya 2: code + nywila mpya.
  static Future<void> forgotReset(String resetToken, String code, String newPassword) =>
      post('forgot/reset', {'resetToken': resetToken, 'code': code.trim(), 'newPassword': newPassword});

  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final body = await put('password', {'oldPassword': oldPassword, 'newPassword': newPassword});
    if (body is Map && body['access_token'] != null) {
      await Session.savePlatformLogin(
        body['access_token'].toString(),
        Map<String, dynamic>.from((body['admin'] as Map?) ?? const {}),
      );
    }
  }
}
