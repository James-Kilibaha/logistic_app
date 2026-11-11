import 'json.dart';

Map<String, double> _doubles(dynamic v) {
  if (v is! Map) return const {};
  return {for (final e in v.entries) e.key.toString(): J.dbl(e.value)};
}

class CoProduct {
  final String description;
  final double cartons;
  final double kg;
  final String? trackNumber;
  final String carrierType;
  final double price;

  const CoProduct({
    required this.description,
    this.cartons = 0,
    this.kg = 0,
    this.trackNumber,
    this.carrierType = '',
    this.price = 0,
  });

  factory CoProduct.fromJson(Map<String, dynamic> j) => CoProduct(
        description: J.str(j['description']),
        cartons: J.dbl(j['cartons']),
        kg: J.dbl(j['kg']),
        trackNumber: J.strOrNull(j['trackNumber']),
        carrierType: J.str(j['carrierType']),
        price: J.dbl(j['price']),
      );
}

class CoInvoice {
  final String id;
  final String invoiceNumber;
  final String status;
  final DateTime? createdAt;
  final double cartons;
  final double kg;
  final double cbm;
  final List<String> carriers;
  final double value;
  final double billed;
  final double paid;
  final double balance;
  final double storageCharge;
  final int storageDays;
  final double discount;
  final String? receiverName;
  final String? pickupCode;
  final int handovers;
  final List<CoProduct> products;

  const CoInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    this.createdAt,
    this.cartons = 0,
    this.kg = 0,
    this.cbm = 0,
    this.carriers = const [],
    this.value = 0,
    this.billed = 0,
    this.paid = 0,
    this.balance = 0,
    this.storageCharge = 0,
    this.storageDays = 0,
    this.discount = 0,
    this.receiverName,
    this.pickupCode,
    this.handovers = 0,
    this.products = const [],
  });

  factory CoInvoice.fromJson(Map<String, dynamic> j) => CoInvoice(
        id: J.str(j['id']),
        invoiceNumber: J.str(j['invoiceNumber']),
        status: J.str(j['status']),
        createdAt: J.date(j['created_at']),
        cartons: J.dbl(j['cartons']),
        kg: J.dbl(j['kg']),
        cbm: J.dbl(j['cbm']),
        carriers: j['carriers'] is List ? [for (final c in j['carriers'] as List) c.toString()] : const [],
        value: J.dbl(j['value']),
        billed: J.dbl(j['billed']),
        paid: J.dbl(j['paid']),
        balance: J.dbl(j['balance']),
        storageCharge: J.dbl(j['storageCharge']),
        storageDays: J.integer(j['storageDays']),
        discount: J.dbl(j['discount']),
        receiverName: J.strOrNull(j['receiverName']),
        pickupCode: J.strOrNull(j['pickupCode']),
        handovers: J.integer(j['handovers']),
        products: J.list(j['products'], CoProduct.fromJson),
      );
}

class CoPayment {
  final String id;
  final DateTime? createdAt;
  final String? receiptNumber;
  final String invoiceId;
  final String? invoiceNumber;
  final String kind;
  final double amount;
  final String currency;
  final String institute;
  final String? note;
  final String? staff;

  const CoPayment({
    required this.id,
    this.createdAt,
    this.receiptNumber,
    required this.invoiceId,
    this.invoiceNumber,
    this.kind = 'PAYMENT',
    this.amount = 0,
    this.currency = 'TZS',
    this.institute = '',
    this.note,
    this.staff,
  });

  bool get isRefund => kind == 'REFUND';

  factory CoPayment.fromJson(Map<String, dynamic> j) => CoPayment(
        id: J.str(j['id']),
        createdAt: J.date(j['created_at']),
        receiptNumber: J.strOrNull(j['receiptNumber']),
        invoiceId: J.str(j['invoiceId']),
        invoiceNumber: J.strOrNull(j['invoiceNumber']),
        kind: J.str(j['kind'], 'PAYMENT'),
        amount: J.dbl(j['amount']),
        currency: J.str(j['currency'], 'TZS'),
        institute: J.str(j['institute']),
        note: J.strOrNull(j['note']),
        staff: J.strOrNull(j['staff']),
      );
}

class CoHandover {
  final String id;
  final String invoiceId;
  final String invoiceNumber;
  final DateTime? createdAt;
  final String collectorName;
  final String? collectorPhone;
  final bool onCredit;
  final String? staff;

  const CoHandover({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    this.createdAt,
    required this.collectorName,
    this.collectorPhone,
    this.onCredit = false,
    this.staff,
  });

  factory CoHandover.fromJson(Map<String, dynamic> j) => CoHandover(
        id: J.str(j['id']),
        invoiceId: J.str(j['invoiceId']),
        invoiceNumber: J.str(j['invoiceNumber']),
        createdAt: J.date(j['created_at']),
        collectorName: J.str(j['collectorName']),
        collectorPhone: J.strOrNull(j['collectorPhone']),
        onCredit: J.boolean(j['onCredit']),
        staff: J.strOrNull(j['staff']),
      );
}

class CoClaim {
  final String id;
  final String invoiceId;
  final String? invoiceNumber;
  final String type;
  final String status;
  final String description;
  final double compensation;
  final DateTime? createdAt;

  const CoClaim({
    required this.id,
    required this.invoiceId,
    this.invoiceNumber,
    required this.type,
    required this.status,
    required this.description,
    this.compensation = 0,
    this.createdAt,
  });

  factory CoClaim.fromJson(Map<String, dynamic> j) => CoClaim(
        id: J.str(j['id']),
        invoiceId: J.str(j['invoiceId']),
        invoiceNumber: J.strOrNull(j['invoiceNumber']),
        type: J.str(j['type']),
        status: J.str(j['status']),
        description: J.str(j['description']),
        compensation: J.dbl(j['compensation']),
        createdAt: J.date(j['created_at']),
      );
}

class CoSms {
  final String id;
  final DateTime? createdAt;
  final String kind;
  final String channel;
  final String text;
  final bool sent;
  final String? invoiceNumber;

  const CoSms({
    required this.id,
    this.createdAt,
    required this.kind,
    this.channel = 'SMS',
    required this.text,
    this.sent = false,
    this.invoiceNumber,
  });

  factory CoSms.fromJson(Map<String, dynamic> j) => CoSms(
        id: J.str(j['id']),
        createdAt: J.date(j['created_at']),
        kind: J.str(j['kind']),
        channel: J.str(j['channel'], 'SMS'),
        text: J.str(j['text']),
        sent: J.boolean(j['sent']),
        invoiceNumber: J.strOrNull(j['invoiceNumber']),
      );
}

class CoMonth {
  final String month;
  final int invoices;
  final double kg;
  final double billed;
  final double paid;

  const CoMonth({required this.month, this.invoices = 0, this.kg = 0, this.billed = 0, this.paid = 0});

  factory CoMonth.fromJson(Map<String, dynamic> j) => CoMonth(
        month: J.str(j['month']),
        invoices: J.integer(j['invoices']),
        kg: J.dbl(j['kg']),
        billed: J.dbl(j['billed']),
        paid: J.dbl(j['paid']),
      );
}

/// Dashibodi ya mteja mmoja: takwimu na kumbukumbu zote za biashara naye.
class CustomerOverview {
  final Map<String, double> stats;
  final DateTime? firstAt;
  final DateTime? lastAt;
  final Map<String, double> carrierKg;
  final Map<String, double> carrierCartons;
  final Map<String, double> byStatus;
  final Map<String, double> byMethod;
  final List<CoMonth> monthly;
  final List<CoInvoice> invoices;
  final List<CoPayment> payments;
  final List<CoHandover> handovers;
  final List<CoClaim> claims;
  final List<CoSms> sms;

  /// Mkopo: kikomo (null = hakuna kikomo), kinachotumika, kinachopatikana.
  final double? creditLimit;
  final double creditUsed;
  final double? creditAvailable;

  /// false: mtumiaji hana ruhusa ya FINANCE (seva imeondoa pesa).
  final bool finance;

  const CustomerOverview({
    this.stats = const {},
    this.firstAt,
    this.lastAt,
    this.carrierKg = const {},
    this.carrierCartons = const {},
    this.byStatus = const {},
    this.byMethod = const {},
    this.monthly = const [],
    this.invoices = const [],
    this.payments = const [],
    this.handovers = const [],
    this.claims = const [],
    this.sms = const [],
    this.creditLimit,
    this.creditUsed = 0,
    this.creditAvailable,
    this.finance = true,
  });

  double stat(String key) => stats[key] ?? 0;

  factory CustomerOverview.fromJson(Map<String, dynamic> j) {
    final s = J.map(j['stats']) ?? const <String, dynamic>{};
    final carriers = J.map(j['byCarrier']) ?? const <String, dynamic>{};
    final credit = J.map(j['credit']) ?? const <String, dynamic>{};
    return CustomerOverview(
      stats: {
        for (final e in s.entries)
          if (e.value is num || (e.value is String && double.tryParse(e.value as String) != null))
            e.key: J.dbl(e.value),
      },
      firstAt: J.date(s['firstAt']),
      lastAt: J.date(s['lastAt']),
      carrierKg: {for (final e in carriers.entries) e.key: J.dbl((J.map(e.value) ?? const {})['kg'])},
      carrierCartons: {for (final e in carriers.entries) e.key: J.dbl((J.map(e.value) ?? const {})['cartons'])},
      byStatus: _doubles(j['byStatus']),
      byMethod: _doubles(j['byMethod']),
      monthly: J.list(j['monthly'], CoMonth.fromJson),
      invoices: J.list(j['invoices'], CoInvoice.fromJson),
      payments: J.list(j['payments'], CoPayment.fromJson),
      handovers: J.list(j['handovers'], CoHandover.fromJson),
      claims: J.list(j['claims'], CoClaim.fromJson),
      sms: J.list(j['sms'], CoSms.fromJson),
      creditLimit: credit['limit'] == null ? null : J.dbl(credit['limit']),
      creditUsed: J.dbl(credit['used']),
      creditAvailable: credit['available'] == null ? null : J.dbl(credit['available']),
      finance: j['finance'] != false,
    );
  }
}
