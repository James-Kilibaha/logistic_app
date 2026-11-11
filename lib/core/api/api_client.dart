import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' show Trans;
import 'package:http/http.dart' as http;

import '../session.dart';
import '../client_info.dart';

/// Kosa kutoka kwa server (au mtandao). `message` iko tayari kuonyeshwa kwa mtumiaji.
class ApiException implements Exception {
  /// `null` = hakuna mawasiliano na server.
  final int? status;
  final String message;

  const ApiException(this.status, this.message);

  bool get isUnauthorized => status == 401;

  /// Backend inarudisha 406 pale mtumiaji hana ruhusa.
  bool get isForbidden => status == 406;

  bool get isNetwork => status == null;

  @override
  String toString() => message;
}

/// Faili moja la kutuma kwenye multipart (mf. sahihi na picha ya makabidhiano).
class UploadFile {
  final String field;
  final Uint8List bytes;
  final String name;

  const UploadFile(this.field, this.bytes, this.name);
}

/// Mawasiliano yote na backend yanapita hapa (Chopper client moja).
///
/// - Anwani ya server inasomwa kutoka [Session.apiBase] kila request, kwa hiyo
///   ikibadilishwa ndani ya app inaanza kutumika papo hapo.
/// - Token inaongezwa yenyewe (`Authorization: Bearer ...`).
/// - Kwenye debug, `CurlInterceptor` inaonyesha amri ya curl ya kila request kwenye console.
/// - Jibu lisilo 2xx linageuzwa kuwa [ApiException] yenye ujumbe wa `detail` kutoka backend.
class Api {
  Api._();

  static const Duration _timeout = Duration(seconds: 40);

  /// Inaitwa pale token imeisha muda au si halali (401) - app inarudi kwenye Login.
  static VoidCallback? onUnauthorized;

  /// Server inarudisha 428 mtumiaji akitakiwa kubadilisha nywila kwanza.
  static VoidCallback? onPasswordChangeRequired;

  /// 402: subscription ya kampuni imeisha (au huduma haipo kwenye mpango) - `code` ni SUBSCRIPTION_EXPIRED n.k.
  static void Function(String message, String? code)? onPaymentRequired;

  /// 403 COMPANY_SUSPENDED: akaunti ya kampuni imesimamishwa na mtoa huduma.
  static void Function(String message)? onCompanySuspended;

  /// Server inarudisha 423 kazi zikiwa zimezuiwa (madai ya gharama hayajajazwa).
  static VoidCallback? onWorkBlocked;

  static final ChopperClient _client = ChopperClient(
    baseUrl: Uri.parse(Session.apiBase),
    converter: const JsonConverter(),
    interceptors: [
      if (kDebugMode) CurlInterceptor(),
      if (kDebugMode) HttpLoggingInterceptor(level: Level.basic),
    ],
  );

  static Map<String, String> get _headers => {
        ...ClientInfo.headers, // app/web na kifaa (kumbukumbu za vitendo)
        if (Session.token.isNotEmpty) 'Authorization': 'Bearer ${Session.token}',
        if (Session.companySlug.isNotEmpty) 'X-Company': Session.companySlug,
      };

  /// Headers za kampuni tu (kwa maombi yasiyopita Chopper: refresh, picha).
  static Map<String, String> get companyHeaders => {
        if (Session.companySlug.isNotEmpty) 'X-Company': Session.companySlug,
      };

  static Uri _path(String path) => Uri.parse(path.startsWith('/') ? path.substring(1) : path);

  /// Ombi moja tu la refresh kwa wakati mmoja (requests nyingi zikipata 401 pamoja).
  static Future<bool>? _refreshing;

  /// Inapata access token mpya kwa refresh token. `false` = imeshindikana (lazima kuingia upya).
  static Future<bool> refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  static Future<bool> _doRefresh() async {
    final refresh = Session.refreshToken;
    if (refresh.isEmpty) return false;
    try {
      final res = await http
          .post(
            Uri.parse('${Session.apiBase}auth/refresh'),
            headers: {'Content-Type': 'application/json', ...companyHeaders, ...ClientInfo.headers},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map || body['access_token'] == null) return false;
      await Session.saveTokens(body['access_token'].toString(), (body['refresh_token'] ?? '').toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Response<dynamic>> _send(Request request, {bool retried = false}) async {
    // Token inakaribia kuisha: pata mpya kabla ya kutuma (hasa kwa multipart isiyoweza kutumwa mara mbili).
    if (!retried && Session.tokenNeedsRefresh) {
      if (await refreshSession()) request = request.copyWith(headers: {...request.headers, ..._headers});
    }

    final Response<dynamic> response;
    try {
      response = await _client.send<dynamic, dynamic>(request).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(null, 'errTimeout'.tr);
    } on http.ClientException {
      throw ApiException(null, 'errNoServer'.tr);
    } catch (e) {
      // Kwenye simu: SocketException / HandshakeException (dart:io haitumiki ili web ifanye kazi).
      final text = e.toString();
      if (text.contains('SocketException') || text.contains('HandshakeException') || text.contains('XMLHttpRequest')) {
        throw ApiException(null, 'errNoServer'.tr);
      }
      rethrow;
    }

    if (response.isSuccessful) return response;

    final int status = response.statusCode;
    if (status == 401 && Session.token.isNotEmpty) {
      if (!retried && !request.multipart && await refreshSession()) {
        return _send(request.copyWith(headers: {...request.headers, ..._headers}), retried: true);
      }
      onUnauthorized?.call();
    }
    if (status == 428) onPasswordChangeRequired?.call();
    final message = _message(response);
    if (status == 402) onPaymentRequired?.call(message, _code(response));
    if (status == 403 && const {'COMPANY_SUSPENDED', 'COMPANY_PENDING', 'COMPANY_REJECTED'}.contains(_code(response))) {
      onCompanySuspended?.call(message);
    }
    if (status == 423) onWorkBlocked?.call();
    throw ApiException(status, message);
  }

  static String? _code(Response<dynamic> response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['code'] != null) return decoded['code'].toString();
    } catch (_) {
      // si JSON
    }
    return null;
  }

  static String _message(Response<dynamic> response) {
    final int status = response.statusCode;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          return first is Map ? (first['msg'] ?? first).toString() : first.toString();
        }
        return detail.toString();
      }
    } catch (_) {
      // si JSON
    }
    if (status == 401) return 'errSession'.tr;
    if (status == 406) return 'errPermission'.tr;
    if (status == 404) return 'errNotFound'.tr;
    if (status >= 500) return 'errServer'.tr;
    return '${'errUnknown'.tr} ($status)';
  }

  static Request _request(String method, String path, {Object? body, Map<String, dynamic>? query}) {
    return Request(
      method,
      _path(path),
      Uri.parse(Session.apiBase),
      body: body,
      parameters: query ?? const {},
      headers: _headers,
    );
  }

  // ------------------------------------------------------------- JSON

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      (await _send(_request(HttpMethod.Get, path, query: query))).body;

  static Future<dynamic> post(String path, [Object? body]) async =>
      (await _send(_request(HttpMethod.Post, path, body: body ?? const <String, dynamic>{}))).body;

  static Future<dynamic> put(String path, [Object? body]) async =>
      (await _send(_request(HttpMethod.Put, path, body: body ?? const <String, dynamic>{}))).body;

  static Future<dynamic> delete(String path) async => (await _send(_request(HttpMethod.Delete, path))).body;

  /// Orodha kutoka kwenye jibu la JSON (`[]` kama jibu si orodha).
  static Future<List<T>> list<T>(
    Future<dynamic> call,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final body = await call;
    if (body is! List) return <T>[];
    return body.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Kitu kimoja kutoka kwenye jibu la JSON.
  static Future<T> one<T>(Future<dynamic> call, T Function(Map<String, dynamic> json) fromJson) async {
    final body = await call;
    if (body is Map) return fromJson(Map<String, dynamic>.from(body));
    throw ApiException(null, 'errUnknown'.tr);
  }

  // ------------------------------------------------------------- PDF / faili

  /// GET inayorudisha faili (mfano backup .zip).
  static Future<Uint8List> getBytes(String path) async {
    final response = await _send(_request(HttpMethod.Get, path));
    return response.bodyBytes;
  }

  /// POST inayorudisha faili (PDF ya invoice au ripoti).
  static Future<Uint8List> postBytes(String path, [Object? body]) async {
    final response = await _send(_request(HttpMethod.Post, path, body: body ?? const <String, dynamic>{}));
    return response.bodyBytes;
  }

  /// multipart/form-data: sehemu za maandishi + faili moja (si lazima).
  /// Faili linatumwa kama bytes ili lifanye kazi kwenye web na simu.
  static Future<dynamic> multipart(
    String path, {
    required Map<String, String> fields,
    Uint8List? fileBytes,
    String? fileName,
    String fileField = 'file',
    List<UploadFile> files = const [],
  }) async {
    final request = Request(
      HttpMethod.Post,
      _path(path),
      Uri.parse(Session.apiBase),
      multipart: true,
      headers: _headers,
      parts: [
        for (final entry in fields.entries) PartValue<String>(entry.key, entry.value),
        if (fileBytes != null)
          PartValue<http.MultipartFile>(
            fileField,
            http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName ?? 'image.jpg'),
          ),
        for (final f in files)
          PartValue<http.MultipartFile>(
            f.field,
            http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.name),
          ),
      ],
    );
    return (await _send(request)).body;
  }

  /// Kupima kama server inapatikana (Login -> mipangilio ya server).
  static Future<bool> ping(String server) async {
    try {
      final uri = Uri.parse('${Session.normalizeServer(server)}/api/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
