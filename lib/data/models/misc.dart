import 'json.dart';
import 'settings.dart';

class Expense {
  final String id;
  final String details;
  final double amount; // TSh
  final String currency;
  final double? amountOriginal;
  final String? officeId;
  final Office? office;
  final DateTime? createdAt;
  final String? categoryId;
  final String? category;
  final String? accountId;
  final String? account;
  final String? boxId; // package id
  final String? boxLabel;
  final String status; // PENDING | APPROVED | REJECTED
  final String? rejectReason;
  final String? approvedBy;
  final String? createdBy;
  final bool hasReceipt;
  final String payStatus; // PAID | PARTIAL | CREDIT
  final double owedTzs;
  final String? supplier;

  const Expense({
    required this.id,
    required this.details,
    required this.amount,
    this.currency = 'TZS',
    this.amountOriginal,
    this.officeId,
    this.office,
    this.createdAt,
    this.categoryId,
    this.category,
    this.accountId,
    this.account,
    this.boxId,
    this.boxLabel,
    this.status = 'APPROVED',
    this.rejectReason,
    this.approvedBy,
    this.createdBy,
    this.hasReceipt = false,
    this.payStatus = 'PAID',
    this.owedTzs = 0,
    this.supplier,
  });

  bool get hasDebt => owedTzs > 0.009;

  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';
  bool get isApproved => status == 'APPROVED';

  /// Kiasi kama kilivyoandikwa (sarafu asili).
  double get entered => amountOriginal ?? amount;

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: J.str(j['id']),
        details: J.str(j['details']),
        amount: J.dbl(j['amount']),
        currency: J.str(j['currency'], 'TZS'),
        amountOriginal: j['amountOriginal'] == null ? null : J.dbl(j['amountOriginal']),
        officeId: J.strOrNull(j['office_id']),
        office: J.first(j['office'], Office.fromJson),
        createdAt: J.date(j['created_at']),
        categoryId: J.strOrNull(j['category_id']),
        category: J.strOrNull(j['category']),
        accountId: J.strOrNull(j['institute_id']),
        account: J.strOrNull(j['institute']),
        boxId: J.strOrNull(j['package_id']),
        boxLabel: J.strOrNull(j['boxId']),
        status: J.str(j['status'], 'APPROVED'),
        rejectReason: J.strOrNull(j['rejectReason']),
        approvedBy: J.strOrNull(j['approvedBy']),
        createdBy: J.strOrNull(j['createdBy']),
        hasReceipt: J.boolean(j['hasReceipt']),
        payStatus: J.str(j['payStatus'], 'PAID'),
        owedTzs: J.dbl(j['owedTzs']),
        supplier: J.strOrNull(j['supplier']),
      );
}

/// Aina za SMS zinazoandaliwa na mfumo.
enum SmsKind {
  received('RECEIVED'),
  shipping('SHIPPING'),
  store('STORE'),
  reminder('REMAINDER'),
  whatsapp('WHATSAPP'),
  receipt('RECEIPT'),
  handover('HANDOVER'),
  storageWarn('STORAGE_WARN'),
  storageOverdue('STORAGE_OVERDUE'),
  eta('ETA'),
  broadcast('BROADCAST'),
  invoiceSms('INVOICE_SMS'),
  quotation('QUOTATION'),
  otpLogin('OTP_LOGIN'),
  otpReset('OTP_RESET'),
  alert('ALERT'),
  custom('CUSTOM');

  /// Aina zisizohifadhiwa kwenye orodha ya SMS (zinatumwa moja kwa moja) - zina swichi tu kwenye Mipangilio.
  bool get settingOnly => this == otpLogin || this == otpReset || this == alert;

  final String code;

  const SmsKind(this.code);

  static SmsKind? fromCode(String code) {
    for (final k in SmsKind.values) {
      if (k.code == code) return k;
    }
    return null;
  }
}

class SmsMessage {
  final String id;
  final String text;
  final String msisdn;
  final String smsFor;
  final bool isSent;
  final String? invoiceId;
  final DateTime? createdAt;

  /// SMS au WHATSAPP
  final String channel;

  /// Sababu ya mwisho ya kushindwa kutuma.
  final String? error;

  /// Ripoti ya kufika: SENT (gateway imepokea), DELIVERED (imefika), FAILED (haikufika); null = haijulikani.
  final String? deliveryStatus;
  final DateTime? deliveredAt;

  /// Salio la FastHub baada ya kutuma ujumbe huu.
  final double? balanceAfter;

  /// Jibu kamili la FastHub (status, headers, body) - kwa uchunguzi / FastHub support.
  final String? gatewayResponse;

  const SmsMessage({
    required this.id,
    required this.text,
    required this.msisdn,
    required this.smsFor,
    this.isSent = false,
    this.invoiceId,
    this.createdAt,
    this.channel = 'SMS',
    this.error,
    this.deliveryStatus,
    this.deliveredAt,
    this.balanceAfter,
    this.gatewayResponse,
  });

  bool get isWhatsApp => channel == 'WHATSAPP';
  bool get isDelivered => deliveryStatus == 'DELIVERED';
  bool get isFailed => deliveryStatus == 'FAILED';

  factory SmsMessage.fromJson(Map<String, dynamic> j) => SmsMessage(
        id: J.str(j['id']),
        text: J.str(j['text']),
        msisdn: J.str(j['msisdn']),
        smsFor: J.str(j['smsFor']),
        isSent: J.boolean(j['isSMSSend']),
        invoiceId: J.strOrNull(j['invoice_id']),
        createdAt: J.date(j['created_at']),
        channel: J.str(j['channel'], 'SMS'),
        error: J.strOrNull(j['error']),
        deliveryStatus: J.strOrNull(j['deliveryStatus']),
        deliveredAt: J.date(j['deliveredAt']),
        balanceAfter: j['balanceAfter'] == null ? null : J.dbl(j['balanceAfter']),
        gatewayResponse: J.strOrNull(j['gatewayResponse']),
      );
}

class DayAmount {
  final DateTime date;
  final double amount;

  const DayAmount(this.date, this.amount);

  factory DayAmount.fromJson(Map<String, dynamic> j) =>
      DayAmount(DateTime.tryParse(J.str(j['date'])) ?? DateTime.now(), J.dbl(j['amount']));
}

class RecentInvoice {
  final String id;
  final String invoiceNumber;
  final String status;
  final String? customerName;
  final double total;
  final DateTime? createdAt;

  const RecentInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    this.customerName,
    this.total = 0,
    this.createdAt,
  });

  factory RecentInvoice.fromJson(Map<String, dynamic> j) => RecentInvoice(
        id: J.str(j['id']),
        invoiceNumber: J.str(j['invoiceNumber']),
        status: J.str(j['status']),
        customerName: J.strOrNull(j['customerName']),
        total: J.dbl(j['total']),
        createdAt: J.date(j['created_at']),
      );
}

class DashboardSummary {
  final Map<String, int> invoices;
  final int customers;
  final int openBoxes;
  final int boxesInTransit;

  /// Mabox yaliyo safarini ambayo ETA imepita.
  final int lateBoxes;
  final double outstandingDebt;
  final double paidToday;
  final double paidThisMonth;
  final double expensesThisMonth;
  final int pendingSms;
  final List<DayAmount> income7Days;
  final List<RecentInvoice> recentInvoices;
  final double storageIncomeThisMonth;
  final double storagePending;
  final int overdueInStore;

  /// Data ya pie charts (mwezi huu).
  final Map<String, double> carrierKg;
  final Map<String, double> paymentsByMethod;
  final Map<String, double> debtAging;

  /// false: mtumiaji hana ruhusa ya DASHBOARD (pesa zimefichwa na seva).
  final bool finance;

  const DashboardSummary({
    this.invoices = const {},
    this.customers = 0,
    this.openBoxes = 0,
    this.boxesInTransit = 0,
    this.lateBoxes = 0,
    this.outstandingDebt = 0,
    this.paidToday = 0,
    this.paidThisMonth = 0,
    this.expensesThisMonth = 0,
    this.pendingSms = 0,
    this.income7Days = const [],
    this.recentInvoices = const [],
    this.storageIncomeThisMonth = 0,
    this.storagePending = 0,
    this.overdueInStore = 0,
    this.carrierKg = const {},
    this.paymentsByMethod = const {},
    this.debtAging = const {},
    this.finance = true,
  });

  int count(String status) => invoices[status] ?? 0;

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final raw = j['invoices'];
    final counts = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) => counts[key.toString()] = J.integer(value));
    }
    return DashboardSummary(
      invoices: counts,
      customers: J.integer(j['customers']),
      openBoxes: J.integer(j['openBoxes']),
      boxesInTransit: J.integer(j['boxesInTransit']),
      lateBoxes: J.integer(j['lateBoxes']),
      outstandingDebt: J.dbl(j['outstandingDebt']),
      paidToday: J.dbl(j['paidToday']),
      paidThisMonth: J.dbl(j['paidThisMonth']),
      expensesThisMonth: J.dbl(j['expensesThisMonth']),
      pendingSms: J.integer(j['pendingSms']),
      income7Days: J.list(j['income7Days'], DayAmount.fromJson),
      recentInvoices: J.list(j['recentInvoices'], RecentInvoice.fromJson),
      storageIncomeThisMonth: J.dbl(j['storageIncomeThisMonth']),
      storagePending: J.dbl(j['storagePending']),
      overdueInStore: J.integer(j['overdueInStore']),
      carrierKg: _doubles(j['carrierKg']),
      paymentsByMethod: _doubles(j['paymentsByMethod']),
      debtAging: _doubles(j['debtAging']),
      finance: j['finance'] != false,
    );
  }
}


/// {"a": 1, "b": "2"} -> {"a": 1.0, "b": 2.0}
Map<String, double> _doubles(dynamic v) {
  if (v is! Map) return const {};
  return {for (final e in v.entries) e.key.toString(): J.dbl(e.value)};
}
