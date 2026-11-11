import 'json.dart';

/// Taarifa ndani ya app (🔔).
class AppNotice {
  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? link;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotice({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.link,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotice.fromJson(Map<String, dynamic> j) => AppNotice(
        id: J.str(j['id']),
        kind: J.str(j['kind']),
        title: J.str(j['title']),
        body: J.strOrNull(j['body']),
        link: J.strOrNull(j['link']),
        isRead: J.boolean(j['isRead']),
        createdAt: J.date(j['created_at']),
      );
}

class NoticeList {
  final int unread;
  final List<AppNotice> items;

  const NoticeList({this.unread = 0, this.items = const []});

  factory NoticeList.fromJson(Map<String, dynamic> j) =>
      NoticeList(unread: J.integer(j['unread']), items: J.list(j['items'], AppNotice.fromJson));
}

/// Matokeo ya kuingiza Excel.
class ImportResult {
  final bool dryRun;
  final bool saved;
  final int rows;
  final int created;
  final int skipped;
  final List<(int, String)> errors;

  const ImportResult({
    this.dryRun = true,
    this.saved = false,
    this.rows = 0,
    this.created = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
        dryRun: J.boolean(j['dryRun'], true),
        saved: J.boolean(j['saved']),
        rows: J.integer(j['rows']),
        created: J.integer(j['created']),
        skipped: J.integer(j['skipped']),
        errors: (j['errors'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => (J.integer(e['row']), J.str(e['message'])))
            .toList(),
      );
}

// ------------------------------------------------------- mizigo iliyochelewa stoo

/// Ankara iliyokaa stoo zaidi ya siku za bure.
class OverdueItem {
  final String invoiceId;
  final String invoiceNumber;
  final String? customerId;
  final String customerName;
  final String phone;
  final int days;
  final int chargeableDays;
  final double chargeUsd;
  final double storageCharge;
  final double balance;
  final DateTime? arrivedAt;
  final DateTime? remindedAt;

  const OverdueItem({
    required this.invoiceId,
    required this.invoiceNumber,
    this.customerId,
    required this.customerName,
    required this.phone,
    this.days = 0,
    this.chargeableDays = 0,
    this.chargeUsd = 0,
    this.storageCharge = 0,
    this.balance = 0,
    this.arrivedAt,
    this.remindedAt,
  });

  factory OverdueItem.fromJson(Map<String, dynamic> j) => OverdueItem(
        invoiceId: J.str(j['invoiceId']),
        invoiceNumber: J.str(j['invoiceNumber']),
        customerId: J.strOrNull(j['customerId']),
        customerName: J.str(j['customerName'], '-'),
        phone: J.str(j['phone']),
        days: J.integer(j['days']),
        chargeableDays: J.integer(j['chargeableDays']),
        chargeUsd: J.dbl(j['chargeUsd']),
        storageCharge: J.dbl(j['storageCharge']),
        balance: J.dbl(j['balance']),
        arrivedAt: J.date(j['arrivedAt']),
        remindedAt: J.date(j['remindedAt']),
      );
}

class OverdueSummary {
  final int freeDays;
  final double chargePerDayUsd;
  final int alertEveryDays;
  final double totalCharge;
  final double totalUsd;
  final List<OverdueItem> items;

  const OverdueSummary({
    this.freeDays = 7,
    this.chargePerDayUsd = 3,
    this.alertEveryDays = 7,
    this.totalCharge = 0,
    this.totalUsd = 0,
    this.items = const [],
  });

  factory OverdueSummary.fromJson(Map<String, dynamic> j) => OverdueSummary(
        freeDays: J.integer(j['freeDays'], 7),
        chargePerDayUsd: J.dbl(j['chargePerDayUsd'], 3),
        alertEveryDays: J.integer(j['alertEveryDays'], 7),
        totalCharge: J.dbl(j['totalCharge']),
        totalUsd: J.dbl(j['totalUsd']),
        items: J.list(j['items'], OverdueItem.fromJson),
      );
}

// --------------------------------------------------------------- mapato ya stoo

class StorageIncomeRow {
  final String invoiceId;
  final String invoiceNumber;
  final String customerName;
  final int days;
  final double storageCharge;
  final double collected;
  final DateTime? paidAt;

  const StorageIncomeRow({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerName,
    this.days = 0,
    this.storageCharge = 0,
    this.collected = 0,
    this.paidAt,
  });

  factory StorageIncomeRow.fromJson(Map<String, dynamic> j) => StorageIncomeRow(
        invoiceId: J.str(j['invoiceId']),
        invoiceNumber: J.str(j['invoiceNumber']),
        customerName: J.str(j['customerName'], '-'),
        days: J.integer(j['days']),
        storageCharge: J.dbl(j['storageCharge']),
        collected: J.dbl(j['collected']),
        paidAt: J.date(j['paidAt']),
      );
}

/// Mapato ya kipindi: jumla = usafirishaji + stoo.
class IncomeBreakdown {
  final double total;
  final double freight;
  final double storage;
  final double pendingInStore;
  final List<StorageIncomeRow> items;

  const IncomeBreakdown({
    this.total = 0,
    this.freight = 0,
    this.storage = 0,
    this.pendingInStore = 0,
    this.items = const [],
  });

  factory IncomeBreakdown.fromJson(Map<String, dynamic> j) => IncomeBreakdown(
        total: J.dbl(j['total']),
        freight: J.dbl(j['freight']),
        storage: J.dbl(j['storage']),
        pendingInStore: J.dbl(j['pendingInStore']),
        items: J.list(j['items'], StorageIncomeRow.fromJson),
      );
}

// --------------------------------------------------------- ujumbe kwa wateja

/// Walengwa wa ujumbe.
enum Audience {
  all('ALL'),
  selected('SELECTED'),
  one('ONE'),
  inStore('IN_STORE'),
  overdue('OVERDUE'),
  debt('DEBT');

  final String code;

  const Audience(this.code);
}

class BroadcastRecipient {
  final String name;
  final String phone;

  const BroadcastRecipient({required this.name, required this.phone});

  factory BroadcastRecipient.fromJson(Map<String, dynamic> j) =>
      BroadcastRecipient(name: J.str(j['name']), phone: J.str(j['phone']));
}

class BroadcastPreview {
  final int count;
  final int segments;
  final int totalSms;
  final String sample;
  final List<BroadcastRecipient> recipients;

  const BroadcastPreview({
    this.count = 0,
    this.segments = 1,
    this.totalSms = 0,
    this.sample = '',
    this.recipients = const [],
  });

  factory BroadcastPreview.fromJson(Map<String, dynamic> j) => BroadcastPreview(
        count: J.integer(j['count']),
        segments: J.integer(j['segments'], 1),
        totalSms: J.integer(j['totalSms']),
        sample: J.str(j['sample']),
        recipients: J.list(j['recipients'], BroadcastRecipient.fromJson),
      );
}

// ------------------------------------------------------- mizigo iliyokabidhiwa

class HandedItem {
  final String description;
  final String? trackNumber;
  final String carrierType;
  final double cartons;

  const HandedItem({required this.description, this.trackNumber, this.carrierType = '', this.cartons = 0});

  factory HandedItem.fromJson(Map<String, dynamic> j) => HandedItem(
        description: J.str(j['description']),
        trackNumber: J.strOrNull(j['trackNumber']),
        carrierType: J.str(j['carrierType']),
        cartons: J.dbl(j['cartons']),
      );
}

/// Kukabidhi mzigo mara moja (ankara inaweza kuwa na awamu kadhaa).
class HandoverRecord {
  final String id;
  final String invoiceId;
  final String invoiceNumber;
  final String customerName;
  final String? customerPhone;
  final String collectorName;
  final String? collectorPhone;
  final String? staffId;
  final String? staffName;
  final bool onCredit;
  final double balance;
  final double cartons;
  final List<String> carriers;
  final List<HandedItem> items;
  final DateTime? createdAt;

  const HandoverRecord({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerName,
    this.customerPhone,
    required this.collectorName,
    this.collectorPhone,
    this.staffId,
    this.staffName,
    this.onCredit = false,
    this.balance = 0,
    this.cartons = 0,
    this.carriers = const [],
    this.items = const [],
    this.createdAt,
  });

  factory HandoverRecord.fromJson(Map<String, dynamic> j) => HandoverRecord(
        id: J.str(j['id']),
        invoiceId: J.str(j['invoiceId']),
        invoiceNumber: J.str(j['invoiceNumber']),
        customerName: J.str(j['customerName'], '-'),
        customerPhone: J.strOrNull(j['customerPhone']),
        collectorName: J.str(j['collectorName']),
        collectorPhone: J.strOrNull(j['collectorPhone']),
        staffId: J.strOrNull(j['staffId']),
        staffName: J.strOrNull(j['staffName']),
        onCredit: J.boolean(j['onCredit']),
        balance: J.dbl(j['balance']),
        cartons: J.dbl(j['cartons']),
        carriers: j['carriers'] is List ? [for (final c in j['carriers'] as List) c.toString()] : const [],
        items: J.list(j['items'], HandedItem.fromJson),
        createdAt: J.date(j['created_at']),
      );

  String get itemsLabel => items.map((i) => '${i.description} (${i.cartons % 1 == 0 ? i.cartons.toInt() : i.cartons})').join(', ');
}

class StaffRef {
  final String id;
  final String name;

  const StaffRef(this.id, this.name);
}

class HandoverPage {
  final int total;
  final List<HandoverRecord> items;
  final List<StaffRef> staff;

  const HandoverPage({this.total = 0, this.items = const [], this.staff = const []});

  factory HandoverPage.fromJson(Map<String, dynamic> j) => HandoverPage(
        total: J.integer(j['total']),
        items: J.list(j['items'], HandoverRecord.fromJson),
        staff: [
          if (j['staff'] is List)
            for (final s in (j['staff'] as List).whereType<Map>()) StaffRef(J.str(s['id']), J.str(s['name'])),
        ],
      );
}

// ------------------------------------------------------- kufunga hesabu ya siku

class CashLine {
  final String? instituteId;
  final String name;
  final double expected;
  final double counted;
  final double difference;
  final int payments;
  final String? note;

  const CashLine({
    this.instituteId,
    required this.name,
    this.expected = 0,
    this.counted = 0,
    this.difference = 0,
    this.payments = 0,
    this.note,
  });

  factory CashLine.fromJson(Map<String, dynamic> j) => CashLine(
        instituteId: J.strOrNull(j['instituteId']),
        name: J.str(j['name']),
        expected: J.dbl(j['expected']),
        counted: J.dbl(j['counted']),
        difference: J.dbl(j['difference']),
        payments: J.integer(j['payments']),
        note: J.strOrNull(j['note']),
      );
}

class CashUp {
  final String id;
  final String day;
  final double expected;
  final double counted;
  final double difference;
  final int payments;
  final String? note;
  final DateTime? closedAt;
  final String? closedBy;
  final int lateCount;
  final double lateAmount;
  final List<CashLine> lines;

  const CashUp({
    required this.id,
    required this.day,
    this.expected = 0,
    this.counted = 0,
    this.difference = 0,
    this.payments = 0,
    this.note,
    this.closedAt,
    this.closedBy,
    this.lateCount = 0,
    this.lateAmount = 0,
    this.lines = const [],
  });

  factory CashUp.fromJson(Map<String, dynamic> j) => CashUp(
        id: J.str(j['id']),
        day: J.str(j['day']),
        expected: J.dbl(j['expected']),
        counted: J.dbl(j['counted']),
        difference: J.dbl(j['difference']),
        payments: J.integer(j['payments']),
        note: J.strOrNull(j['note']),
        closedAt: J.date(j['closedAt']),
        closedBy: J.strOrNull(j['closedBy']),
        lateCount: J.integer(j['lateCount']),
        lateAmount: J.dbl(j['lateAmount']),
        lines: J.list(j['lines'], CashLine.fromJson),
      );
}

/// Malipo ya siku kwa kila njia kabla ya kufunga.
class CashExpected {
  final String day;
  final List<CashLine> methods;
  final double total;
  final int payments;
  final CashUp? closed;

  const CashExpected({required this.day, this.methods = const [], this.total = 0, this.payments = 0, this.closed});

  factory CashExpected.fromJson(Map<String, dynamic> j) => CashExpected(
        day: J.str(j['day']),
        methods: J.list(j['methods'], CashLine.fromJson),
        total: J.dbl(j['total']),
        payments: J.integer(j['payments']),
        closed: J.first(j['closed'], CashUp.fromJson),
      );
}
