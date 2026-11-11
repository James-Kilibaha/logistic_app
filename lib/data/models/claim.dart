import 'json.dart';

/// Dai la mzigo ulioharibika (DAMAGED), kupotea (LOST) au katoni pungufu (SHORT).
class CargoClaim {
  final String id;
  final String invoiceId;
  final String? productId;
  final String type;
  final double? cartons;
  final String description;
  final String status; // OPEN, APPROVED, REJECTED, SETTLED
  final double compensation;
  final String settlement; // NONE, DISCOUNT, REFUND
  final String? resolution;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final bool hasPhoto;
  final String? invoiceNumber;
  final String? customerName;
  final String? productName;
  final String? reportedBy;
  final String? resolvedByName;

  const CargoClaim({
    required this.id,
    required this.invoiceId,
    this.productId,
    required this.type,
    this.cartons,
    required this.description,
    required this.status,
    this.compensation = 0,
    this.settlement = 'NONE',
    this.resolution,
    this.resolvedAt,
    this.createdAt,
    this.hasPhoto = false,
    this.invoiceNumber,
    this.customerName,
    this.productName,
    this.reportedBy,
    this.resolvedByName,
  });

  bool get isOpen => status == 'OPEN';

  factory CargoClaim.fromJson(Map<String, dynamic> j) => CargoClaim(
        id: J.str(j['id']),
        invoiceId: J.str(j['invoice_id']),
        productId: J.strOrNull(j['product_id']),
        type: J.str(j['type']),
        cartons: j['cartons'] == null ? null : J.dbl(j['cartons']),
        description: J.str(j['description']),
        status: J.str(j['status'], 'OPEN'),
        compensation: J.dbl(j['compensation']),
        settlement: J.str(j['settlement'], 'NONE'),
        resolution: J.strOrNull(j['resolution']),
        resolvedAt: J.date(j['resolvedAt']),
        createdAt: J.date(j['created_at']),
        hasPhoto: J.boolean(j['hasPhoto']),
        invoiceNumber: J.strOrNull(j['invoiceNumber']),
        customerName: J.strOrNull(j['customerName']),
        productName: J.strOrNull(j['productName']),
        reportedBy: J.strOrNull(j['reportedBy']),
        resolvedByName: J.strOrNull(j['resolvedByName']),
      );
}
