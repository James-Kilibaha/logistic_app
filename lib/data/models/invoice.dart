import 'customer.dart';
import 'json.dart';
import 'settings.dart';

/// Hatua za mzigo (lazima zilingane na `EInvoiceStatus` ya backend).
enum InvoiceStatus {
  open('OPEN'),
  parking('PARKING'),
  shipping('SHIPPING'),
  store('STORE'),
  delivered('DELIVERED'),
  completed('COMPLETED'),
  blocked('BLOCKED'),
  other('');

  final String code;

  const InvoiceStatus(this.code);

  static InvoiceStatus fromCode(String? code) {
    switch (code) {
      case 'OPEN':
        return InvoiceStatus.open;
      case 'PARKING':
        return InvoiceStatus.parking;
      case 'SHIPPING':
      case 'PROCESSING':
        return InvoiceStatus.shipping;
      case 'STORE':
      case 'ARRIVE':
      case 'RECEIVED':
      case 'PIKING':
      case 'DELIVERING':
        return InvoiceStatus.store;
      case 'DELIVERED':
        return InvoiceStatus.delivered;
      case 'COMPLETED':
      case 'CLOSE':
        return InvoiceStatus.completed;
      case 'BLOCKED':
      case 'BLOCK':
        return InvoiceStatus.blocked;
      default:
        return InvoiceStatus.other;
    }
  }

  /// Hatua kuu tano kwa mpangilio (zinazoonyeshwa kwenye mstari wa maendeleo).
  static const List<InvoiceStatus> flow = [
    InvoiceStatus.open,
    InvoiceStatus.parking,
    InvoiceStatus.shipping,
    InvoiceStatus.store,
    InvoiceStatus.completed,
  ];
}

/// Kipande kimoja cha `history`: "SHIPPING_2026-10-13T12:00:00".
class StatusEvent {
  final InvoiceStatus status;
  final String code;
  final DateTime? at;

  const StatusEvent(this.status, this.code, this.at);

  static List<StatusEvent> parse(String history) {
    final events = <StatusEvent>[];
    for (final raw in history.split(',')) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      final i = part.indexOf('_');
      final code = i < 0 ? part : part.substring(0, i);
      final when = i < 0 ? null : DateTime.tryParse(part.substring(i + 1));
      events.add(StatusEvent(InvoiceStatus.fromCode(code), code, when));
    }
    return events;
  }
}

class Product {
  final String id;
  final String description;
  final double unitPrice;
  final double quantities;
  final double weight;
  final String? trackNumber;
  final String carrierType;
  final double? length;
  final double? width;
  final double? height;
  final String? path;

  /// Code ya ofisi ya mzigo huu: iko kwenye SMS na lebo; mpokeaji anaionyesha kuuchukua.
  final String? officeCode;
  final String? invoiceId;
  final String? priceId;
  final Price? price;
  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.description,
    required this.unitPrice,
    required this.quantities,
    required this.weight,
    this.trackNumber,
    this.carrierType = 'AIR',
    this.length,
    this.width,
    this.height,
    this.path,
    this.officeCode,
    this.invoiceId,
    this.priceId,
    this.price,
    this.createdAt,
  });

  bool get isSea => carrierType.toUpperCase() == 'SEA';

  /// Mita za ujazo (CBM) za katoni moja: vipimo viko kwa sentimita.
  double get cartonCbm {
    final l = length ?? 0, w = width ?? 0, h = height ?? 0;
    if (l <= 0 || w <= 0 || h <= 0) return 0;
    return l * w * h / 1000000;
  }

  /// CBM ya mzigo wote: katoni moja x idadi ya katoni.
  double get cbm => cartonCbm * (quantities < 1 ? 1 : quantities);

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: J.str(j['id']),
        description: J.str(j['description']),
        unitPrice: J.dbl(j['unitPrice']),
        quantities: J.dbl(j['quantities']),
        weight: J.dbl(j['weight']),
        trackNumber: J.strOrNull(j['trackNumber'] ?? j['qrcodeOrBarcodeTrack']),
        carrierType: J.str(j['carrierType'], 'AIR'),
        length: j['length'] == null ? null : J.dbl(j['length']),
        width: j['width'] == null ? null : J.dbl(j['width']),
        height: j['height'] == null ? null : J.dbl(j['height']),
        path: J.strOrNull(j['path']),
        officeCode: J.strOrNull(j['officeCode']),
        invoiceId: J.strOrNull(j['invoice_id']),
        priceId: J.strOrNull(j['price_id']),
        price: J.first(j['price'], Price.fromJson),
        createdAt: J.date(j['created_at']),
      );
}

class Receiver {
  final String id;
  final String name;
  final String phoneNumber;
  final String trackNumber;
  final int active;
  final String? invoiceId;

  const Receiver({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.trackNumber,
    this.active = 1,
    this.invoiceId,
  });

  factory Receiver.fromJson(Map<String, dynamic> j) => Receiver(
        id: J.str(j['id']),
        name: J.str(j['name']),
        phoneNumber: J.str(j['phoneNumber']),
        trackNumber: J.str(j['trackNumber'] ?? j['qrcodeOrBarcodeTrack']),
        active: J.integer(j['active'], 1),
        invoiceId: J.strOrNull(j['invoice_id']),
      );
}

class Payment {
  final String id;

  /// Daima TSh (kama alilipa kwa dola, [amountOriginal] na [currency] zinaonyesha alicholeta).
  final double paid;
  final String kind;
  final String currency;
  final double? amountOriginal;
  final double? rate;
  final String? note;
  final String? receiptNumber;
  final String? instituteId;
  final Institute? institute;
  final DateTime? createdAt;

  const Payment({
    required this.id,
    required this.paid,
    this.kind = 'PAYMENT',
    this.currency = 'TZS',
    this.amountOriginal,
    this.rate,
    this.note,
    this.receiptNumber,
    this.instituteId,
    this.institute,
    this.createdAt,
  });

  bool get isRefund => kind == 'REFUND';

  bool get isForeign => amountOriginal != null && currency != 'TZS';

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: J.str(j['id']),
        paid: J.dbl(j['paid']),
        kind: J.str(j['kind'], 'PAYMENT'),
        currency: J.str(j['currency'], 'TZS'),
        amountOriginal: j['amountOriginal'] == null ? null : J.dbl(j['amountOriginal']),
        rate: j['rate'] == null ? null : J.dbl(j['rate']),
        note: J.strOrNull(j['note']),
        receiptNumber: J.strOrNull(j['receiptNumber']),
        instituteId: J.strOrNull(j['institute_id']),
        institute: J.first(j['institute'], Institute.fromJson),
        createdAt: J.date(j['created_at']),
      );
}

/// Ushahidi wa kukabidhi mzigo.
class Handover {
  final String id;
  final String collectorName;
  final String collectorPhone;
  final String? idType;
  final String? idNumber;
  final bool isReceiver;
  final bool onCredit;
  final double balance;
  final bool hasSignature;
  final bool hasPhoto;
  final String? note;
  final String? staffName;
  final DateTime? createdAt;

  /// Katoni zilizochukuliwa kwenye makabidhiano haya (tupu = mzigo wote).
  final List<HandoverLine> items;

  /// Ni sehemu tu ya mzigo.
  final bool partial;

  const Handover({
    required this.id,
    required this.collectorName,
    required this.collectorPhone,
    this.idType,
    this.idNumber,
    this.isReceiver = true,
    this.onCredit = false,
    this.balance = 0,
    this.hasSignature = false,
    this.hasPhoto = false,
    this.note,
    this.staffName,
    this.createdAt,
    this.items = const [],
    this.partial = false,
  });

  double get cartons => items.fold<double>(0, (s, i) => s + i.cartons);

  factory Handover.fromJson(Map<String, dynamic> j) => Handover(
        id: J.str(j['id']),
        collectorName: J.str(j['collectorName']),
        collectorPhone: J.str(j['collectorPhone']),
        idType: J.strOrNull(j['idType']),
        idNumber: J.strOrNull(j['idNumber']),
        isReceiver: J.boolean(j['isReceiver'], true),
        onCredit: J.boolean(j['onCredit']),
        balance: J.dbl(j['balance']),
        hasSignature: J.boolean(j['hasSignature']) || J.strOrNull(j['signaturePath']) != null,
        hasPhoto: J.boolean(j['hasPhoto']) || J.strOrNull(j['photoPath']) != null,
        note: J.strOrNull(j['note']),
        staffName: J.strOrNull(j['staffName']),
        createdAt: J.date(j['created_at']),
        items: J.list(j['items'], HandoverLine.fromJson),
        partial: J.boolean(j['partial']),
      );
}

class HandoverLine {
  final String productId;
  final String description;
  final double cartons;

  const HandoverLine({required this.productId, required this.description, required this.cartons});

  factory HandoverLine.fromJson(Map<String, dynamic> j) => HandoverLine(
        productId: J.str(j['productId']),
        description: J.str(j['description']),
        cartons: J.dbl(j['cartons']),
      );
}

/// Kilichobaki stoo kwa bidhaa moja (kukabidhi kwa awamu).
class RemainingLine {
  final String productId;
  final String description;
  final String? trackNumber;
  final double cartons;
  final double collected;
  final double remaining;

  /// Mzigo huu una code ya ofisi (mchukuaji lazima aionyeshe).
  final bool needsCode;

  const RemainingLine({
    required this.productId,
    required this.description,
    this.trackNumber,
    required this.cartons,
    required this.collected,
    required this.remaining,
    this.needsCode = false,
  });

  factory RemainingLine.fromJson(Map<String, dynamic> j) => RemainingLine(
        productId: J.str(j['productId']),
        description: J.str(j['description']),
        trackNumber: J.strOrNull(j['trackNumber']),
        cartons: J.dbl(j['cartons']),
        collected: J.dbl(j['collected']),
        remaining: J.dbl(j['remaining']),
        needsCode: J.boolean(j['needsCode']),
      );
}

class HandoverStatus {
  final List<Handover> handovers;
  final List<RemainingLine> remaining;
  final bool complete;

  /// Ankara ina code ya ofisi: mchukuaji lazima aionyeshe.
  final bool needsCode;

  const HandoverStatus({
    this.handovers = const [],
    this.remaining = const [],
    this.complete = false,
    this.needsCode = false,
  });

  double get remainingCartons => remaining.fold<double>(0, (s, r) => s + r.remaining);

  double get totalCartons => remaining.fold<double>(0, (s, r) => s + r.cartons);

  factory HandoverStatus.fromJson(Map<String, dynamic> j) => HandoverStatus(
        handovers: J.list(j['handovers'], Handover.fromJson),
        remaining: J.list(j['remaining'], RemainingLine.fromJson),
        complete: J.boolean(j['complete']),
        needsCode: J.boolean(j['needsCode']),
      );
}

/// Deni la invoice: `amount` = jumla, `paid` = kilicholipwa, `balance` = kilichobaki.
class Debt {
  final String id;

  /// Gharama ya usafirishaji.
  final double amount;
  final double balance;
  final double paid;
  final String status;

  /// Siku mzigo umekaa stoo.
  final int days;
  final double storageCharge;
  final double discount;
  final String? discountNote;
  final String? invoiceId;
  final List<Payment> payments;
  final DateTime? createdAt;

  const Debt({
    required this.id,
    required this.amount,
    required this.balance,
    required this.paid,
    required this.status,
    this.days = 0,
    this.storageCharge = 0,
    this.discount = 0,
    this.discountNote,
    this.invoiceId,
    this.payments = const [],
    this.createdAt,
  });

  bool get isPaid => status == 'PAID' || balance < 1;

  /// Jumla ya kulipwa: usafirishaji + stoo - punguzo.
  double get total => amount + storageCharge - discount;

  double get progress => total <= 0 ? 0 : (paid / total).clamp(0, 1).toDouble();

  factory Debt.fromJson(Map<String, dynamic> j) {
    final payments = J.list(j['payment'], Payment.fromJson)
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return Debt(
      id: J.str(j['id']),
      amount: J.dbl(j['amount']),
      balance: J.dbl(j['debt']),
      paid: J.dbl(j['paid']),
      status: J.str(j['status']),
      days: J.integer(j['days']),
      storageCharge: J.dbl(j['storageCharge']),
      discount: J.dbl(j['discount']),
      discountNote: J.strOrNull(j['discountNote']),
      invoiceId: J.strOrNull(j['invoice_id']),
      payments: payments,
      createdAt: J.date(j['created_at']),
    );
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String statusCode;
  final String history;
  final String? pdfPath;
  final String? customerId;

  /// Ofisi ya kuchukulia mzigo (tawi).
  final String? officeId;
  final Customer? customer;
  final List<Product> products;
  final Receiver? receiver;
  final Debt? debt;

  /// Makabidhiano yote (ya zamani kwanza) - mzigo unaweza kuchukuliwa kwa awamu.
  final List<Handover> handovers;
  final DateTime? createdAt;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.statusCode,
    this.history = '',
    this.pdfPath,
    this.customerId,
    this.officeId,
    this.customer,
    this.products = const [],
    this.receiver,
    this.debt,
    this.handovers = const [],
    this.createdAt,
  });

  /// Makabidhiano ya mwisho (null = bado hajachukua chochote).
  Handover? get handover => handovers.isEmpty ? null : handovers.last;

  InvoiceStatus get status => InvoiceStatus.fromCode(statusCode);

  List<StatusEvent> get events => StatusEvent.parse(history);

  double get total => products.fold<double>(0, (sum, p) => sum + p.unitPrice);

  double get totalWeight => products.fold<double>(0, (sum, p) => sum + p.weight);

  double get totalQuantity => products.fold<double>(0, (sum, p) => sum + p.quantities);

  String get number => '#$invoiceNumber';

  Invoice copyWith({Customer? customer}) => Invoice(
        id: id,
        invoiceNumber: invoiceNumber,
        statusCode: statusCode,
        history: history,
        pdfPath: pdfPath,
        customerId: customerId,
        officeId: officeId,
        customer: customer ?? this.customer,
        products: products,
        receiver: receiver,
        debt: debt,
        handovers: handovers,
        createdAt: createdAt,
      );

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: J.str(j['id']),
        invoiceNumber: J.str(j['invoiceNumber']),
        statusCode: J.str(j['status']),
        history: J.str(j['history']),
        pdfPath: J.strOrNull(j['path']),
        customerId: J.strOrNull(j['customer_id']),
        officeId: J.strOrNull(j['office_id']),
        customer: J.first(j['customer'], Customer.fromJson),
        products: J.list(j['product'], Product.fromJson),
        receiver: J.first(j['receiver'], Receiver.fromJson),
        debt: J.first(j['debt'], Debt.fromJson),
        handovers: J.list(j['handover'], Handover.fromJson)
          ..sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000))),
        createdAt: J.date(j['created_at']),
      );
}
