import 'package:get/get.dart';

import 'json.dart';

/// Kiwango cha sarafu (mfano USD 1 = TSh 2,600). Kiwango kipya kikiwekwa, cha zamani kinazuiwa.
class Currency {
  final String id;
  final String name;
  final double buy;
  final String local;
  final bool isBlocked;
  final DateTime? createdAt;

  const Currency({
    required this.id,
    required this.name,
    required this.buy,
    this.local = 'TSHS',
    this.isBlocked = false,
    this.createdAt,
  });

  factory Currency.fromJson(Map<String, dynamic> j) => Currency(
        id: J.str(j['id']),
        name: J.str(j['name']),
        buy: J.dbl(j['buy']),
        local: J.str(j['local'], 'TSHS'),
        isBlocked: J.boolean(j['isBlocked']),
        createdAt: J.date(j['created_at']),
      );
}

/// Bei ya usafirishaji: `cost` (kwa sarafu ya `currency`) kwa kila kilo `weight`.
class Price {
  final String id;
  final String name;
  final double weight;
  final double cost;

  /// `KG` (kwa kilo) au `CBM` (kwa mita za ujazo - meli).
  final String unit;
  final String? currencyId;
  final Currency? currency;
  final bool isBlocked;
  final DateTime? createdAt;

  const Price({
    required this.id,
    required this.name,
    required this.weight,
    required this.cost,
    this.unit = 'KG',
    this.currencyId,
    this.currency,
    this.isBlocked = false,
    this.createdAt,
  });

  bool get isCbm => unit == 'CBM';

  /// 'kg' au 'CBM'.
  String get unitLabel => isCbm ? 'CBM' : 'kg';

  /// Gharama ya kipimo kimoja (kilo au CBM) kwa shilingi (TSh).
  double get costPerKgLocal {
    final per = weight > 0 ? weight : 1;
    return cost / per * (currency?.buy ?? 1);
  }

  /// Gharama (TSh) ya kiasi [qty] (kilo, au CBM kama [isCbm]).
  double totalFor(double qty) => qty * costPerKgLocal;

  factory Price.fromJson(Map<String, dynamic> j) {
    final currencies = J.list(j['currency'], Currency.fromJson);
    Currency? active;
    for (final c in currencies) {
      if (active == null || !c.isBlocked) active = c;
    }
    return Price(
      id: J.str(j['id']),
      name: J.str(j['name']),
      weight: J.dbl(j['weight'], 1),
      cost: J.dbl(j['cost']),
      unit: J.str(j['unit'], 'KG').toUpperCase(),
      currencyId: J.strOrNull(j['currency_id']),
      currency: active,
      isBlocked: J.boolean(j['isBlocked']),
      createdAt: J.date(j['created_at']),
    );
  }
}

/// Taasisi ya fedha (benki / mobile money) inayopokea malipo.
class Institute {
  final String id;
  final String name;
  final String accountNo;
  final String currencyType;
  final bool isBlocked;

  /// CASH | BANK | MOBILE (uhasibu)
  final String kind;

  const Institute({
    required this.id,
    required this.name,
    required this.accountNo,
    required this.currencyType,
    this.isBlocked = false,
    this.kind = 'BANK',
  });

  /// Jina · namba · aina · sarafu - ili mtumiaji ajue ni akaunti ya sarafu ipi.
  String get label => '$name · $accountNo · ${'accKind_$kind'.tr} · ${currencyType.toUpperCase()}';

  factory Institute.fromJson(Map<String, dynamic> j) => Institute(
        id: J.str(j['id']),
        name: J.str(j['name']),
        accountNo: J.str(j['accountNo']),
        currencyType: J.str(j['currencyType']),
        isBlocked: J.boolean(j['isBlocked']),
        kind: J.str(j['kind'], 'BANK'),
      );
}

class Office {
  final String id;
  final String name;
  final String location;
  final String? phoneNumber;
  final bool isBlocked;

  const Office({
    required this.id,
    required this.name,
    required this.location,
    this.phoneNumber,
    this.isBlocked = false,
  });

  String get label => location.isEmpty ? name : '$name · $location';

  factory Office.fromJson(Map<String, dynamic> j) => Office(
        id: J.str(j['id']),
        name: J.str(j['name']),
        location: J.str(j['location']),
        phoneNumber: J.strOrNull(j['phoneNumber']),
        isBlocked: J.boolean(j['isBlocked']),
      );
}

/// Kuwasha/kuzima aina ya SMS (RECEIVED, SHIPPING, STORE, REMAINDER, WHATSAPP).
class SmsSetting {
  final String id;
  final String name;
  final bool enabled;

  const SmsSetting({required this.id, required this.name, required this.enabled});

  factory SmsSetting.fromJson(Map<String, dynamic> j) => SmsSetting(
        id: J.str(j['id']),
        name: J.str(j['name']),
        enabled: J.boolean(j['action']),
      );
}
