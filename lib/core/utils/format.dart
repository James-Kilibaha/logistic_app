import 'package:flutter/services.dart';
import 'package:get/get.dart' show Trans;
import 'package:intl/intl.dart';

/// Kuonyesha pesa, namba na tarehe kwa mtindo mmoja kila mahali.
class Fmt {
  Fmt._();

  static final NumberFormat _money = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _money2 = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _num = NumberFormat('#,##0.##', 'en_US');
  static final NumberFormat _compact = NumberFormat.compact(locale: 'en_US');

  /// TSh 1,250,000
  static String tsh(num? value) => 'TSh ${_money.format(value ?? 0)}';

  /// 1,250,000 (bila "TSh")
  static String money(num? value) => _money.format(value ?? 0);

  static String money2(num? value) => _money2.format(value ?? 0);

  /// 1.2M, 350K
  static String compact(num? value) => _compact.format(value ?? 0);

  /// 12.5 / 3
  static String number(num? value) => _num.format(value ?? 0);

  static String kg(num? value) => '${_num.format(value ?? 0)} kg';

  static String date(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

  static String dateTime(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);

  static String time(DateTime? d) => d == null ? '—' : DateFormat('HH:mm').format(d);

  /// "Leo 14:20", "Jana 09:00", au tarehe.
  static String relative(DateTime? d) {
    if (d == null) return '—';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '${'today'.tr} ${time(d)}';
    if (diff == 1) return '${'yesterday'.tr} ${time(d)}';
    return date(d);
  }

  /// Siku fupi ya wiki kwa chati (Jt, Jn ... / Mon, Tue ...).
  static String weekday(DateTime d) => 'wd${d.weekday}'.tr;

  /// Kusoma namba iliyoandikwa na mtumiaji ("1,250,000" -> 1250000).
  static double? parse(String? text) {
    if (text == null) return null;
    final clean = text.replaceAll(',', '').replaceAll(' ', '').trim();
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  /// +255 754 111 222 (namba ikiwa sahihi), '—' ikiwa haipo.
  static String phone(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '—';
    final n = Phone.normalize(raw);
    if (n == null) return raw.replaceAll(RegExp(r'\s+'), '');
    if (!Phone.isLocal(n)) return n; // kimataifa: +8613812345678
    return '${n.substring(0, 4)} ${n.substring(4, 7)} ${n.substring(7, 10)} ${n.substring(10)}';
  }
}

/// Namba za simu - sawa na backend (core/phone.py): "+" + code ya nchi + namba.
/// - Tanzania: 0712 345 678 / 712345678 / 255712345678 / +255 712 345 678  ->  +255712345678
/// - Nchi nyingine: +86 138 1234 5678 / 008613812345678 / 8613812345678     ->  +8613812345678
/// Namba si lazima.
class Phone {
  Phone._();

  static const String countryCode = '255';
  static const String example = '+255712345678';
  static const String exampleIntl = '+8613812345678';

  static bool isLocal(String? normalized) => (normalized ?? '').startsWith('+$countryCode');

  /// +255XXXXXXXXX au +<code><namba>, au `null` kama ni tupu au si sahihi.
  static String? normalize(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    final international = value.startsWith('+') || digits.startsWith('00');
    if (digits.startsWith('00')) digits = digits.substring(2);

    // 1. Tanzania
    String? national;
    if (digits.startsWith(countryCode) && digits.length == countryCode.length + 9) {
      national = digits.substring(countryCode.length);
    } else if (!international && digits.startsWith('0') && digits.length == 10) {
      national = digits.substring(1);
    } else if (!international && digits.length == 9) {
      national = digits;
    }
    if (national != null) {
      return RegExp(r'^[1-9]\d{8}$').hasMatch(national) ? '+$countryCode$national' : null;
    }

    // 2. Nchi nyingine (E.164: tarakimu 8-15, ya kwanza si 0)
    if (digits.startsWith(countryCode) || digits.startsWith('0')) return null;
    if (!international && digits.length < 10) return null;
    if (digits.length >= 8 && digits.length <= 15) return '+$digits';
    return null;
  }

  /// Kwa kutuma kwa server: namba sahihi, au '' kama haikuandikwa.
  static String forApi(String? raw) => normalize(raw) ?? (raw ?? '').trim();

  /// Tarakimu za kutafuta bila kujali muundo: 0712.. / +255712.. -> 712..
  static String searchDigits(String q) {
    var d = q.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith(countryCode) && d.length > countryCode.length + 2) {
      d = d.substring(countryCode.length);
    } else if (d.startsWith('0')) {
      d = d.substring(1);
    }
    return d;
  }

  /// Kama [stored] inalingana na utafutaji [q] (kwa tarakimu).
  static bool matches(String? stored, String q) {
    final d = searchDigits(q);
    if (d.length < 3) return false;
    return (stored ?? '').replaceAll(RegExp(r'\D'), '').contains(d);
  }
}

/// Inaweka koma za maelfu wakati mtumiaji anaandika kiasi (1,250,000).
class ThousandsFormatter extends TextInputFormatter {
  final bool allowDecimal;

  ThousandsFormatter({this.allowDecimal = false});

  static final NumberFormat _f = NumberFormat('#,##0', 'en_US');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final pattern = allowDecimal ? RegExp(r'^\d*\.?\d{0,2}$') : RegExp(r'^\d*$');
    if (!pattern.hasMatch(raw)) return oldValue;

    final parts = raw.split('.');
    final whole = parts[0].isEmpty ? '' : _f.format(int.tryParse(parts[0]) ?? 0);
    final text = parts.length > 1 ? '$whole.${parts[1]}' : whole;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
