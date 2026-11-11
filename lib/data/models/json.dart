/// Visaidizi vya kusoma JSON kwa usalama (backend wakati mwingine inatuma
/// namba kama string, au uhusiano kama orodha yenye kitu kimoja).
class J {
  J._();

  static String str(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

  static String? strOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static double dbl(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? fallback;
    return fallback;
  }

  static int integer(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool boolean(dynamic v, [bool fallback = false]) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return fallback;
  }

  /// Backend inahifadhi muda wa UTC bila "Z" - tunaugeuza kuwa saa za kifaa.
  static DateTime? date(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s);
    final parsed = DateTime.tryParse(hasZone || s.length <= 10 ? s : '${s}Z');
    return parsed?.toLocal();
  }

  static Map<String, dynamic>? map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is List && v.isNotEmpty && v.first is Map) return Map<String, dynamic>.from(v.first as Map);
    return null;
  }

  static List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
    if (v is List) {
      return v.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (v is Map) return [fromJson(Map<String, dynamic>.from(v))];
    return <T>[];
  }

  /// Uhusiano wa kitu kimoja ambao backend inautuma kama orodha (`"customer": [{...}]`).
  static T? first<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
    final m = map(v);
    return m == null ? null : fromJson(m);
  }
}
