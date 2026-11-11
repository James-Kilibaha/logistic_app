import 'json.dart';

/// Box (kifurushi) cha kusafirisha mizigo ya invoice kadhaa.
class Box {
  final String id;
  final String boxId;
  final String packageType;
  final double weight;
  final String trackNumber;
  final List<String> productIds;
  final List<String> invoiceIds;
  final bool isCollect;
  final bool isBoxClose;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Lilipofungwa na kusafirishwa, tarehe ya kutarajia kufika (ETA) na lilipofika stoo.
  final DateTime? shippedAt;
  final DateTime? eta;
  final DateTime? arrivedAt;

  const Box({
    required this.id,
    required this.boxId,
    this.packageType = 'GENERAL',
    this.weight = 0,
    this.trackNumber = '',
    this.productIds = const [],
    this.invoiceIds = const [],
    this.isCollect = false,
    this.isBoxClose = false,
    this.createdAt,
    this.updatedAt,
    this.shippedAt,
    this.eta,
    this.arrivedAt,
  });

  /// Siku ambazo box lililo safarini limechelewa (0 = halijachelewa / halina ETA).
  int get daysLate {
    if (!inTransit || eta == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = today.difference(DateTime(eta!.year, eta!.month, eta!.day)).inDays;
    return d > 0 ? d : 0;
  }

  bool get isLate => daysLate > 0;

  /// Linapakiwa (bado halijafungwa).
  bool get isOpen => !isBoxClose && !isCollect;

  /// Limefungwa na kusafirishwa, bado halijafika stoo.
  bool get inTransit => isBoxClose && !isCollect;

  /// Limefika stoo.
  bool get arrived => isCollect;

  int get productCount => productIds.length;

  /// 'AIR' (box la ndege) au 'SEA' (container ya meli); `null` kwa mabox ya zamani.
  String? get carrier {
    final t = packageType.toUpperCase();
    return t == 'AIR' || t == 'SEA' ? t : null;
  }

  bool get isContainer => carrier == 'SEA';

  /// Je, bidhaa ya usafiri [carrierType] inaweza kuwekwa humu?
  bool accepts(String carrierType) => carrier == null || carrier == carrierType.toUpperCase();

  static List<String> _ids(dynamic v) =>
      J.str(v).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  factory Box.fromJson(Map<String, dynamic> j) => Box(
        id: J.str(j['id']),
        boxId: J.str(j['boxId']),
        packageType: J.str(j['packageType'], 'GENERAL'),
        weight: J.dbl(j['weight']),
        trackNumber: J.str(j['trackNumber'] ?? j['qrcodeOrBarcodeTrack']),
        productIds: _ids(j['productList']),
        invoiceIds: _ids(j['invoiceList']),
        isCollect: J.boolean(j['isCollect']),
        isBoxClose: J.boolean(j['isBoxClose']),
        createdAt: J.date(j['created_at']),
        updatedAt: J.date(j['update_at']),
        shippedAt: J.date(j['shippedAt']),
        eta: J.date(j['eta']),
        arrivedAt: J.date(j['arrivedAt']),
      );
}

/// Bidhaa pamoja na taarifa za invoice/mteja/mpokeaji wake (kwa kupakia mabox).
class BoxProduct {
  final String id;
  final String description;
  final String? trackNumber;

  /// Code ya ofisi (iko kwenye QR ya lebo).
  final String? officeCode;
  final String carrierType;
  final double weight;
  final double quantities;
  final double unitPrice;

  /// Ujazo (m³) wa mzigo wote (meli).
  final double cbm;
  final String? path;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? customerName;
  final String? customerPhone;
  final String? receiverName;
  final String? receiverPhone;

  const BoxProduct({
    required this.id,
    required this.description,
    this.trackNumber,
    this.officeCode,
    this.carrierType = 'AIR',
    this.weight = 0,
    this.quantities = 0,
    this.unitPrice = 0,
    this.cbm = 0,
    this.path,
    this.invoiceId,
    this.invoiceNumber,
    this.customerName,
    this.customerPhone,
    this.receiverName,
    this.receiverPhone,
  });

  factory BoxProduct.fromJson(Map<String, dynamic> j) => BoxProduct(
        id: J.str(j['id']),
        description: J.str(j['description']),
        trackNumber: J.strOrNull(j['trackNumber']),
        officeCode: J.strOrNull(j['officeCode']),
        carrierType: J.str(j['carrierType'], 'AIR'),
        weight: J.dbl(j['weight']),
        quantities: J.dbl(j['quantities']),
        unitPrice: J.dbl(j['unitPrice']),
        cbm: J.dbl(j['cbm']),
        path: J.strOrNull(j['path']),
        invoiceId: J.strOrNull(j['invoiceId']),
        invoiceNumber: J.strOrNull(j['invoiceNumber']),
        customerName: J.strOrNull(j['customerName']),
        customerPhone: J.strOrNull(j['customerPhone']),
        receiverName: J.strOrNull(j['receiverName']),
        receiverPhone: J.strOrNull(j['receiverPhone']),
      );
}
