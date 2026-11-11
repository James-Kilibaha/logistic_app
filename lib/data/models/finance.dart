import 'json.dart';

/// Gharama moja ya kusafirisha box (nauli, ushuru, clearing ...).
class BoxCost {
  final String id;
  final String category;
  final double amount;
  final String currency;
  final double rate;
  final double amountTzs;
  final String? note;
  final DateTime? createdAt;

  /// PAID | PARTIAL | CREDIT (null = ya zamani, imelipwa)
  final String? payStatus;
  final double paidTzs;
  final double owedTzs;
  final String? supplier;

  // kwa orodha ya madeni (payables)
  final String? packageId;
  final String? boxId;
  final String? createdBy;

  const BoxCost({
    required this.id,
    required this.category,
    required this.amount,
    required this.currency,
    required this.rate,
    required this.amountTzs,
    this.note,
    this.createdAt,
    this.payStatus,
    this.paidTzs = 0,
    this.owedTzs = 0,
    this.supplier,
    this.packageId,
    this.boxId,
    this.createdBy,
  });

  bool get hasDebt => owedTzs > 0.009;

  factory BoxCost.fromJson(Map<String, dynamic> j) => BoxCost(
        id: J.str(j['id']),
        category: J.str(j['category']),
        amount: J.dbl(j['amount']),
        currency: J.str(j['currency'], 'TZS'),
        rate: J.dbl(j['rate'], 1),
        amountTzs: J.dbl(j['amountTzs']),
        note: J.strOrNull(j['note']),
        createdAt: J.date(j['created_at']),
        payStatus: J.strOrNull(j['payStatus']),
        paidTzs: J.dbl(j['paidTzs']),
        owedTzs: J.dbl(j['owedTzs']),
        supplier: J.strOrNull(j['supplier']),
        packageId: J.strOrNull(j['package_id']),
        boxId: J.strOrNull(j['boxId']),
        createdBy: J.strOrNull(j['createdBy']),
      );
}

/// Faida ya box moja.
class BoxProfit {
  final String packageId;
  final String boxId;
  final String packageType;
  final String? trackNumber;
  final DateTime? closedAt;
  final int items;
  final int invoices;
  final double kg;
  final double cbm;
  final double revenue;
  final double storageCharges;
  final double costs;
  final double profit;
  final double margin;
  final double costPerKg;
  final Map<String, double> byCategory;

  const BoxProfit({
    required this.packageId,
    required this.boxId,
    required this.packageType,
    this.trackNumber,
    this.closedAt,
    this.items = 0,
    this.invoices = 0,
    this.kg = 0,
    this.cbm = 0,
    this.revenue = 0,
    this.storageCharges = 0,
    this.costs = 0,
    this.profit = 0,
    this.margin = 0,
    this.costPerKg = 0,
    this.byCategory = const {},
  });

  double get income => revenue + storageCharges;

  bool get isSea => packageType.toUpperCase() == 'SEA';

  factory BoxProfit.fromJson(Map<String, dynamic> j) => BoxProfit(
        packageId: J.str(j['packageId']),
        boxId: J.str(j['boxId']),
        packageType: J.str(j['packageType'], 'AIR'),
        trackNumber: J.strOrNull(j['trackNumber']),
        closedAt: J.date(j['closedAt']),
        items: J.integer(j['items']),
        invoices: J.integer(j['invoices']),
        kg: J.dbl(j['kg']),
        cbm: J.dbl(j['cbm']),
        revenue: J.dbl(j['revenue']),
        storageCharges: J.dbl(j['storageCharges']),
        costs: J.dbl(j['costs']),
        profit: J.dbl(j['profit']),
        margin: J.dbl(j['margin']),
        costPerKg: J.dbl(j['costPerKg']),
        byCategory: (J.map(j['byCategory']) ?? const {}).map((k, v) => MapEntry(k, J.dbl(v))),
      );
}

class ProfitReport {
  final List<BoxProfit> rows;
  final double revenue;
  final double costs;
  final double profit;
  final double margin;

  const ProfitReport({this.rows = const [], this.revenue = 0, this.costs = 0, this.profit = 0, this.margin = 0});

  factory ProfitReport.fromJson(Map<String, dynamic> j) => ProfitReport(
        rows: J.list(j['rows'], BoxProfit.fromJson),
        revenue: J.dbl(j['revenue']),
        costs: J.dbl(j['costs']),
        profit: J.dbl(j['profit']),
        margin: J.dbl(j['margin']),
      );
}

/// Deni la mteja mmoja kwa umri.
class AgingCustomer {
  final String customerId;
  final String name;
  final String phone;
  final int invoices;
  final int oldestDays;
  final double total;
  final Map<String, double> buckets;

  const AgingCustomer({
    required this.customerId,
    required this.name,
    required this.phone,
    this.invoices = 0,
    this.oldestDays = 0,
    this.total = 0,
    this.buckets = const {},
  });

  factory AgingCustomer.fromJson(Map<String, dynamic> j, List<String> keys) => AgingCustomer(
        customerId: J.str(j['customerId']),
        name: J.str(j['customerName']),
        phone: J.str(j['phone']),
        invoices: J.integer(j['invoices']),
        oldestDays: J.integer(j['oldestDays']),
        total: J.dbl(j['total']),
        buckets: {for (final k in keys) k: J.dbl(j[k])},
      );
}

class AgingReport {
  final List<String> buckets;
  final Map<String, double> totals;
  final double total;
  final List<AgingCustomer> customers;

  const AgingReport({this.buckets = const [], this.totals = const {}, this.total = 0, this.customers = const []});

  factory AgingReport.fromJson(Map<String, dynamic> j) {
    final keys = (j['buckets'] as List? ?? const []).map((e) => e.toString()).toList();
    return AgingReport(
      buckets: keys,
      totals: (J.map(j['totals']) ?? const {}).map((k, v) => MapEntry(k, J.dbl(v))),
      total: J.dbl(j['total']),
      customers: (j['customers'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AgingCustomer.fromJson(Map<String, dynamic>.from(e), keys))
          .toList(),
    );
  }
}
