import 'json.dart';

/// Hali za makadirio ya bei.
const List<String> quotationStatuses = ['DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'CONVERTED'];

/// Bidhaa moja ndani ya makadirio. Ndege = kilo; meli (container) = CBM na tani.
class QuotationItem {
  final String? id;
  final String description;
  final String carrierType;
  final double quantities;
  final double weight;
  final double cbm;
  final double? length;
  final double? width;
  final double? height;
  final String? priceId;
  final String unit;
  final double rate;
  final double amount;

  /// true: kiasi kimeandikwa kwa mkono (hakihesabiwi upya).
  final bool manual;

  const QuotationItem({
    this.id,
    required this.description,
    this.carrierType = 'AIR',
    this.quantities = 1,
    this.weight = 0,
    this.cbm = 0,
    this.length,
    this.width,
    this.height,
    this.priceId,
    this.unit = 'KG',
    this.rate = 0,
    this.amount = 0,
    this.manual = false,
  });

  bool get isSea => carrierType == 'SEA';
  double get tons => weight / 1000;

  factory QuotationItem.fromJson(Map<String, dynamic> j) => QuotationItem(
        id: J.strOrNull(j['id']),
        description: J.str(j['description']),
        carrierType: J.str(j['carrierType'], 'AIR'),
        quantities: J.dbl(j['quantities'], 1),
        weight: J.dbl(j['weight']),
        cbm: J.dbl(j['cbm']),
        length: j['length'] == null ? null : J.dbl(j['length']),
        width: j['width'] == null ? null : J.dbl(j['width']),
        height: j['height'] == null ? null : J.dbl(j['height']),
        priceId: J.strOrNull(j['priceId'] ?? j['price_id']),
        unit: J.str(j['unit'], 'KG'),
        rate: J.dbl(j['rate']),
        amount: J.dbl(j['amount']),
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'carrierType': carrierType,
        'quantities': quantities,
        'weight': weight,
        if (isSea && cbm > 0) 'cbm': cbm,
        if (length != null) 'length': length,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (priceId != null) 'priceId': priceId,
        if (manual) 'amount': amount,
      };

  QuotationItem copyWith({
    String? description,
    String? carrierType,
    double? quantities,
    double? weight,
    double? cbm,
    double? amount,
    double? rate,
    String? unit,
    bool? manual,
  }) =>
      QuotationItem(
        id: id,
        description: description ?? this.description,
        carrierType: carrierType ?? this.carrierType,
        quantities: quantities ?? this.quantities,
        weight: weight ?? this.weight,
        cbm: cbm ?? this.cbm,
        length: length,
        width: width,
        height: height,
        priceId: priceId,
        unit: unit ?? this.unit,
        rate: rate ?? this.rate,
        amount: amount ?? this.amount,
        manual: manual ?? this.manual,
      );
}

class Quotation {
  final String id;
  final String number;
  final String status;
  final bool expired;
  final String? customerId;
  final String customerName;
  final String? phoneNumber;
  final DateTime? validUntil;
  final String? note;
  final double total;
  final String? invoiceId;
  final String? invoiceNumber;
  final List<QuotationItem> items;
  final double kg;
  final double cbm;
  final double cartons;
  final DateTime? createdAt;

  const Quotation({
    required this.id,
    required this.number,
    required this.status,
    this.expired = false,
    this.customerId,
    required this.customerName,
    this.phoneNumber,
    this.validUntil,
    this.note,
    this.total = 0,
    this.invoiceId,
    this.invoiceNumber,
    this.items = const [],
    this.kg = 0,
    this.cbm = 0,
    this.cartons = 0,
    this.createdAt,
  });

  bool get isConverted => status == 'CONVERTED';
  bool get canEdit => !isConverted;

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: J.str(j['id']),
        number: J.str(j['number']),
        status: J.str(j['status'], 'DRAFT'),
        expired: J.boolean(j['expired']),
        customerId: J.strOrNull(j['customerId']),
        customerName: J.str(j['customerName']),
        phoneNumber: J.strOrNull(j['phoneNumber']),
        validUntil: J.date(j['validUntil']),
        note: J.strOrNull(j['note']),
        total: J.dbl(j['total']),
        invoiceId: J.strOrNull(j['invoiceId']),
        invoiceNumber: J.strOrNull(j['invoiceNumber']),
        items: J.list(j['items'], QuotationItem.fromJson),
        kg: J.dbl(j['kg']),
        cbm: J.dbl(j['cbm']),
        cartons: J.dbl(j['cartons']),
        createdAt: J.date(j['created_at']),
      );
}
